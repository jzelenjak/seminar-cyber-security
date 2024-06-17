#!/bin/bash
#
# This script is the main script to compute statistics on a JSON file from the Ransomwhere website (https://api.ransomwhe.re/export).
# To download the file you can run: curl -sL "https://api.ransomwhe.re/export" | jq --indent 0 '.result' > data.json
#
# The computed statistics include:
# - General statistics (total number of transactions, payment sum in BTC and USD, mean ransom sizes, time range, addresses, etc.)
# - Timeline of ransom transactions per year (the number of transactions, the payment sum in BTC, the payment sum in USD)
# - Timeline of ransom transactions per month (the number of transactions, the payment sum in BTC, the payment sum in USD)
# - Timeline of ransomware families per month (the number of transactions, the payment sum in BTC, the payment sum in USD)
# - (Optionally) The number of transactions and the number of addresses for a family of choice
#
# For the monthly timeline of ransomware families, the computed statistics for each ransomware family in one month include:
# - The number of transactions in that month
# - The payment sum in BTC in that month
# - The payment sum in USD in that month
# - The number of (unique) used addresses in that month
# - The number of (unique) known addresses so far (sort of a cumulative sum)
# Furthermore, for each family the totals for the corresponding statistics are also computed.
#   Note: for totals the used addresses are equal to the known addresses (we know all addresses the family has used).
# See below in the script for the lines regarding removing totals and saving the output to a csv file.


set -euo pipefail
IFS=$'\n\t'

umask 077

# The Bitcoin amounts in Ransomwhere dataset are in Satoshi
BITCOIN_FACTOR=100000000

function usage() {
    echo -e "Usage: $0 data.json\n"
    echo -e "\tdata.json - the current up-to-date version of the dataset (available on: https://api.ransomwhe.re/export)"
}

function print_title() {
    echo -ne "\e[1;91m"
    echo -n "$1"
    echo -e "\e[0m"
}

function print_result() {
    echo -ne "\e[1;96m"
    echo -ne "$1"
    echo -e "\e[0m"
}

function print_misc() {
    echo -ne "\e[1;93m"
    echo -ne "$1"
    echo -e "\e[0m"
}

function print_general_stats() {
    # Expects the full JSON file (data.json)

    print_title "Total number of transactions"
    print_result $(jq '.[].transactions | length' "$1" | paste -d '+' -s | bc | awk '{ printf("%d\n", $1); }')

    print_title "Total payment sum (BTC)"
    print_result $(jq '.[].transactions.[].amount' "$1" | paste -d '+' -s | bc | awk -v bitcoin_factor="$BITCOIN_FACTOR" '{ printf("%f\n", $1 / bitcoin_factor); }')

    print_title "Total payment sum (USD)"
    print_result $(jq '.[].transactions.[].amountUSD' "$1" | paste -d '+' -s | bc | awk '{ printf("%.2f\n", $1); }')

    print_title "Means for ransom sizes (BTC, USD)"
    print_result $(jq -r '.[] | .transactions.[] | { amount: .amount, amountUSD: .amountUSD } | [ .amount, .amountUSD] | @csv' "$1" | awk -F, -v bitcoin_factor="$BITCOIN_FACTOR" '{ sumBTC += $1 / bitcoin_factor; sumUSD += $2; count += 1;} END { printf("Mean (BTC): %f, Mean (USD): %.2f\n", sumBTC / count, sumUSD / count); }')

    print_title "Time range of transactions"
    transactions=$(jq '.[].transactions.[].time' "$1" |
                    awk '{ $1 = strftime("%Y-%m-%d %H:%M:%S", $1); print $0; }' | sort |
                    awk 'NR == 1 { print "First transaction: " $0; }; END { print "Last transaction: " $0; }')
    print_result "$transactions"

    address_entries=$(jq -r '.[] | { address: .address, family: .family, createdAt: .createdAt, updatedAt: .updatedAt, trans: .transactions | length } | [ .address, .family, .createdAt, .updatedAt, .trans ] | @csv' "$1" | tr -d '"')
    transactions=$(echo -e "$address_entries" | awk -F, '$NF != 0 { print $0 }')
    no_transactions=$(echo -e "$address_entries" | awk -F, '$NF == 0 { print $0 }')

    total_addresses=$(echo -e "$address_entries" | cut -d, -f1 | sort -u | awk '{ count++; } END { printf("%d\n", count); }')
    empty_addresses=$(echo -e "$no_transactions" | cut -d, -f1 | sort -u | awk '{ count++; } END { printf("%d\n", count); }')

    total_families=$(echo -e "$address_entries" | cut -d, -f2 | sort -u)
    non_empty_families=$(echo -e "$transactions" | cut -d, -f2 | sort -u)
    families_with_empty_addresses=$(echo -e "$no_transactions" | cut -d, -f2 | sort -u)
    stats_families_with_empty_addresses=$(echo -e "$no_transactions" | cut -d, -f2 | sort | uniq -c | sort -rn | awk '{ print $2 ": " $1; }')
    stats_families_with_empty_addresses_one_line=$(echo -e "$stats_families_with_empty_addresses" | awk 'NR == 1 { printf("%s", $0); count++; } NR > 1 { printf(", %s", $0); count++; } END { printf(" (%d families in total)\n", count); }')
    empty_families=$(comm -13 <(echo -e "$non_empty_families") <(echo -e "$families_with_empty_addresses"))

    print_title "Total number of families"
    print_result $(echo -e "$total_families" | wc -l)
    print_title "Total number of non-empty families"
    print_result $(echo -e "$non_empty_families" | wc -l)
    print_title "Total number of empty families"
    print_result $(echo -e "$empty_families" | wc -l)

    print_title "Total number of addresses"
    print_result "$total_addresses"
    print_title "Number of empty addresses (and the corresponding families)"
    print_result "$empty_addresses"
    print_misc "$stats_families_with_empty_addresses_one_line"
}

function compute_timeline_years() {
    # Expects the full JSON file (data.json)

    jq -r '.[] | .transactions.[] | [ .time, .amount, .amountUSD ] | @csv' "$1" |
        awk -F, -v bitcoin_factor="$BITCOIN_FACTOR" '
            BEGIN {
                printf("Year,Count,Sum (BTC),Sum (USD),Average (BTC),Average (USD)\n");
            }
            {
                $1 = strftime("%Y", $1);
                count[$1] += 1;
                sum_btc[$1] += $2 / bitcoin_factor;
                sum_usd[$1] += $3;
            }
            END {
                for (year in count) {
                    avg_btc = sum_btc[year] / count[year];
                    avg_usd = sum_usd[year] / count[year];
                    fmt_str = "%s,%d,%f,%.2f,%f,%.2f\n";
                    printf(fmt_str, year, count[year], sum_btc[year], sum_usd[year], avg_btc, avg_usd);
                }
            }' |
            sort -t, -k 1,1 -g
}

function print_timeline_years() {
    # Expects the output of the compute_timeline_years function

    print_title "Timeline of transactions (years)"
    timeline_years_pretty=$(echo -e "$1" | tr ',' '\t' | column -t -s $'\t')
    print_result "$timeline_years_pretty"
}

function compute_timeline_months() {
    # Expects the full JSON file (data.json)

    jq -r '.[] | .transactions.[] | [ .time, .amount, .amountUSD ] | @csv' "$1" |
        awk -F, -v bitcoin_factor="$BITCOIN_FACTOR" '
            BEGIN {
                printf("Month,Count,Sum (BTC),Sum (USD),Average (BTC),Average (USD)\n");
            }
            {
                $1 = strftime("%Y-%m", $1);
                count[$1] += 1;
                sum_btc[$1] += $2 / bitcoin_factor;
                sum_usd[$1] += $3;
            } END {
                for (month in count) {
                    avg_btc = sum_btc[month] / count[month];
                    avg_usd = sum_usd[month] / count[month];
                    fmt_str =  "%s,%d,%f,%.2f,%f,%.2f\n";
                    printf(fmt_str, month, count[month], sum_btc[month], sum_usd[month], avg_btc, avg_usd);
                }
            }' |
            sort -t, -k 1,1 -g
}

function print_timeline_months() {
    # Expects the output of the compute_timeline_months function

    print_title "Timeline of transactions (months)"
    timeline_months_pretty=$(echo -e "$1" | tr ',' '\t' | column -t -s $'\t')
    print_result "$timeline_months_pretty"
}


function compute_timeline_families() {
    # Expects the full JSON file (data.json)

    jq -r '.[] | .family as $family | .address as $address | .transactions[] | [$family, .time, $address, .amount, .amountUSD] | @csv' "$1" | tr -d '"' |
        sort -t, -k1,1 -k2,2 |  # Sorting is very important here for the dates and families
        awk -F, -v bitcoin_factor="$BITCOIN_FACTOR" '
            BEGIN {
                printf("0.Family,Month,Count,Sum (BTC),Sum (USD),Used Addresses,Known Addresses\n");
            }
            {
                # More on 2d arrays: https://www.gnu.org/software/gawk/manual/html_node/Multidimensional.html
                # Format:    Family, Timestamp,                           Address   BTC,               USD
                # Example: WannaCry,1632310212,12t9YDPgwueZ9NyMgw519p7AA8isjr6SMw,26346,11.480139828412979
                $2 = strftime("%Y-%m", $2);  # Convert the date
                count[$1,$2] += 1;
                btc = $4 / bitcoin_factor;
                usd = $5;
                sum_btc[$1,$2] += btc;
                sum_usd[$1,$2] += usd;
                total_count[$1] += 1;
                total_sum_btc[$1] += btc;
                total_sum_usd[$1] += usd;
                last_month[$1] = $2;

                # Check if we have already seen this ransomware family with this address
                # `seen_addresses` is only used for the check, `known_addresses_total` is a global count so far (including previous months)
                if (!seen_addresses[$1,$3]++) {
                    known_addresses_total[$1] += 1;
                }
                known_addresses[$1,$2] = known_addresses_total[$1];

                # Check if we have already seen this ransomware family with this address during this month
                if (!seen_addresses_month[$1,$2,$3]++) {
                    used_addresses_month[$1,$2] += 1;
                }

            }
            END {
                fmt_str = "%s,%s,%d,%f,%.2f,%d,%d\n";

                for (combined in count) {
                    split(combined, separate, SUBSEP);

                    family = separate[1];
                    month = separate[2];
                    count_family = count[family,month];
                    sum_btc_family = sum_btc[family,month];
                    sum_usd_family = sum_usd[family,month];
                    used_addresses_family = used_addresses_month[family,month];
                    known_addresses_family = known_addresses[family,month];

                    printf(fmt_str, family, month, count_family, sum_btc_family, sum_usd_family, used_addresses_family, known_addresses_family);

                    # Print the total values
                    if (month == last_month[family]) {
                        # Here total used addresses and total known addresses are the same (we know all addresses they have used)
                        printf(fmt_str, family, "Total", total_count[family], total_sum_btc[family], total_sum_usd[family], known_addresses_family, known_addresses_family);
                    }
                }
            }' |
            sort -t, -k1,1 -k2,2 |
            sed 's/0.Family/Family/'
}

function print_timeline_families() {
    # Expects the output of the compute_timeline_families function

    print_title "Timeline of transactions per family"
    timeline_families_pretty=$(echo -e "$1" | tr ',' '\t' | column -t -s $'\t')
    print_misc "$timeline_families_pretty"
}

function print_transactions_for_family() {
    # Expects the full JSON file (data.json) and the ransomware family of interest

    print_title "$2:"
    result=$(jq -r '.[] | { address: .address, family: .family, trans: .transactions | length } | [ .address, .family, .trans ] | @csv' "$1" | tr -d '"' | awk -F, -v family="$2" '$2 == family { print $0; }' | awk -F, '!visited[$1]++ { addresses += 1; } { sum += $3; } END { printf("Unique addresses: %d\nNumber of transactions: %d\n", addresses, sum); }')
    print_misc "$result"
}


# Check if exactly one argument has been provided
[[ $# -ne 1 ]] && { usage >&2 ; exit 1; }

# Check if the provided file exists
[[ -f "$1" ]] || { echo "File $1 does not exist." >&2 ; exit 1; }

# Transaction timestamps are in UTC
export TZ="UTC"
# For consistent sorting
export LC_ALL=en_US.UTF-8

data="$1"


echo -e "\e[1;92mWelcome to $0! How about this? \e[0m"

# Print general statistics: total number of addresses, total number of transactions, total payment sum (BTC and USD) etc.
print_general_stats "$data"

# Print the payment timeline per year
timeline_years=$(compute_timeline_years "$data")
print_timeline_years "$timeline_years"
echo -e "$timeline_years" > timeline_years.csv

# Print the payment timeline per month
timeline_months=$(compute_timeline_months "$data")
print_timeline_months "$timeline_months"
echo -e "$timeline_months" > timeline_months.csv

# Print the timeline of ransomware families per month
timeline_families=$(compute_timeline_families "$data")
# Remove "Total" (if needed)
timeline_families=$(echo -e "$timeline_families" | awk -F, '$2 != "Total" { print $0; }')
print_timeline_families "$timeline_families"
echo -e "$timeline_families" > timeline_families.csv

# Print the number of transactions and the number of addresses for a family of choice
# print_transactions_for_family "$data" "Locky"
# print_transactions_for_family "$data" "Conti"
# print_transactions_for_family "$data" "WannaCry"

echo -e "\e[1;95mThis script has been sponsored by Smaragdakis et al.!\e[0m"
echo -e "\e[1;95mHave a nice day!\e[0m"
