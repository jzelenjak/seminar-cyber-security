#!/usr/bin/env python
#
# This script plots all ransomware families found in the file timeline_families.csv.
# In order to get the file timeline_families.csv, run the script run_stats.sh.
# For better readability, the families have been split into three groups based on the highest monthly payment sum in USD.


import datetime
import sys

import matplotlib.dates as md
import matplotlib.pyplot as plt
import matplotlib.ticker as mt
import numpy as np


# The file is assumed to be comma-separated (i.e. in the csv format)
file_separator = ","
if len(sys.argv) != 2:
    print(f"Usage: python {sys.argv[0]} timeline_families.csv\n\n       Run run_stats.sh to get timeline_families.csv file")
    exit(1)


dateformat = "%Y-%m"
datelocator = md.MonthLocator(interval=3)
num_cols_legend = 5

families = dict()
with open(sys.argv[1], "r") as file:
    for line in file.readlines()[1:]:  # Skip the header
        # Format: Family,Month,Count,Sum (BTC),Sum (USD)
        # Example: Conti,2017-12,1,0.166500,1940.923832
        parts = line.split(file_separator)
        family = parts[0]
        if parts[1] == "Total":  # Skip totals, in case they are present in the csv file
            continue
        month = datetime.datetime.strptime(parts[1], dateformat)
        count = int(parts[2])
        sum_btc = float(parts[3])
        sum_usd = float(parts[4])

        if not family in families:
            # Example: {"Conti": {"month": [2017-12,...], "count": [1,...], "sum_btc": [0.166500,...], "sum_usd": [1940.923832,...]},...}
            families[family] = dict()
            families[family]["month"] = []
            families[family]["count"] = []
            families[family]["sum_btc"] = []
            families[family]["sum_usd"] = []
            families[family]["colour"] = np.random.rand(3,)
        families[family]["month"].append(month)
        families[family]["count"].append(count)
        families[family]["sum_btc"].append(sum_btc)
        families[family]["sum_usd"].append(sum_usd)

# Splitting into groups based on the largest monthly payment sum in USD
# Thresholds $1000 and $50000, respectively
SMALL_THRESHOLD = 1000
MEDIUM_THRESHOLD = 50000
small, medium, large = [], [], []
for family in families:
    max_sum_usd = max(families[family]["sum_usd"])
    if max_sum_usd < SMALL_THRESHOLD:
        small.append(family)
    elif max_sum_usd < MEDIUM_THRESHOLD:
        medium.append(family)
    else:
        large.append(family)

print(f"Small (< {SMALL_THRESHOLD} USD):", len(small))
print(f"Medium (< {MEDIUM_THRESHOLD} USD):", len(medium))
print(f"Large (>= {MEDIUM_THRESHOLD} USD):", len(large))


def plot_family_group(family_names, group_name):
    fig, axes = plt.subplots(3)
    fig.suptitle(f"Timeline of transactions of different ransomware families ({group_name})", fontsize=20)

    formatter = mt.ScalarFormatter()
    formatter.set_scientific(False)

    metrics = ["count", "sum_btc", "sum_usd"]
    titles = ["Number of transactions", "Payment sum in BTC", "Payment sum in USD"]

    for i, metric in enumerate(metrics):
        ax = axes[i]
        title = titles[i]

        for family_name in family_names:
            month = families[family_name]["month"]
            stats = families[family_name][metric]
            colour = families[family_name]["colour"]
            ax.plot(month, stats, color=colour, marker='o', label=family_name)

        ax.set_title(title, fontsize=18)
        ax.xaxis.set_major_formatter(md.DateFormatter(dateformat))
        ax.xaxis.set_major_locator(datelocator)
        ax.yaxis.set_major_formatter(formatter)
        ax.tick_params(labelrotation=25)
        ax.legend(ncol=num_cols_legend, fontsize="small")
        ax.grid()
        for item in (ax.get_xticklabels() + ax.get_yticklabels()):
            item.set_fontsize(14)
        if metric != "sum_btc" or group_name == "large":  # Skip btc for small and medium, since they have small y-scale
            ax.get_yaxis().set_major_formatter(mt.FuncFormatter(lambda x, p: format(int(x), ',')))
        ax.tick_params(axis='y', labelrotation=25)

    fig.autofmt_xdate(rotation=25)
    plt.gcf().set_size_inches(22, 12, forward=True)
    plt.tight_layout()

    #plt.savefig(f"timeline_families_{group_name}.png")
    plt.show()
    fig.clf()


plot_family_group(small, "small")
plot_family_group(medium, "medium")
plot_family_group(large, "large")
