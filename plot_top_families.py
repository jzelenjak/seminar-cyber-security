#!/usr/bin/env python
#
# This script plots the timeline of the top 15 ransomware families based on the number of transactions, the payment sum in BTC and the payment sum in USD.
# The script takes the file timeline_families.csv as input. Run run_stats.sh script to get this file.
# Instead of 15 another number could be used.


import datetime
import sys

import numpy as np
import matplotlib.dates as md
import matplotlib.pyplot as plt
import matplotlib.ticker as mt


# The file is assumed to be comma-separated (i.e. in the csv format)
file_separator = ","
if len(sys.argv) != 2:
    print(f"Usage: python {sys.argv[0]} timeline_families.csv\n\n       Run run_stats.sh to get timeline_families.csv file")
    exit(1)


topN = 15
dateformat = "%Y-%m"
datelocator = md.MonthLocator(interval=3)
scale = "linear"
usd_factor = 1  # Use 1000000 to convert to millions

num_cols_legend = 5
font_size_legend = "medium"
# For colours see: https://matplotlib.org/stable/gallery/color/named_colors.html
colours = ["red", "darkcyan", "black", "darkorange", "dodgerblue", "magenta", "gold", "limegreen", "blueviolet", "chocolate", "olivedrab", "lawngreen", "darkgreen", "lightseagreen", "silver", "blue", "olive", "violet", "tan", "darkred", "hotpink", "khaki", "dimgrey", "salmon", "sandybrown"]

families = dict()
min_month = datetime.datetime.max
max_month = datetime.datetime.min
with open(sys.argv[1], "r") as file:
    for line in file.readlines()[1:]:  # Skip the header
        # Format: Family,Month,Count,Sum (BTC),Sum (USD)
        # Example: Conti,2017-12,1,0.166500,1940.923832
        parts = line.split(file_separator)
        family = parts[0]
        if family == "BlackCat":
            continue
        if parts[1] == "Total":  # Skip totals, in case they are present in the csv file
            continue
        month = datetime.datetime.strptime(parts[1], dateformat)
        min_month = min(min_month, month)
        max_month = max(max_month, month)
        count = int(parts[2])
        sum_btc = float(parts[3])
        sum_usd = float(parts[4])

        if not family in families:
            # Example: {"Conti": {"month": [2017-12,...], "count": [1,...], "sum_btc": [0.166500,...], "sum_usd": [1940.923832,...], "total_sum_usd" : ...},...}
            families[family] = dict()
            families[family]["month"] = []
            families[family]["count"] = []
            families[family]["sum_btc"] = []
            families[family]["sum_usd"] = []
            families[family]["total_count"] = 0
            families[family]["total_sum_btc"] = 0
            families[family]["total_sum_usd"] = 0
        families[family]["month"].append(month)
        families[family]["count"].append(count)
        families[family]["sum_btc"].append(sum_btc)
        families[family]["sum_usd"].append(sum_usd / usd_factor)
        families[family]["total_count"] += count
        families[family]["total_sum_btc"] += sum_btc
        families[family]["total_sum_usd"] += sum_usd

# Splitting into groups
families_by_count = {k: v for k, v in sorted(families.items(), key=lambda item: item[1]["total_count"], reverse=True)}
families_by_btc = {k: v for k, v in sorted(families.items(), key=lambda item: item[1]["total_sum_btc"], reverse=True)}
families_by_usd = {k: v for k, v in sorted(families.items(), key=lambda item: item[1]["total_sum_usd"], reverse=True)}
top_families_count = list(families_by_count.keys())[:topN]
top_families_btc = list(families_by_btc.keys())[:topN]
top_families_usd = list(families_by_usd.keys())[:topN]

fig, axes = plt.subplots(3)

metrics = ["count", "sum_btc", "sum_usd"]
titles = [f"Top {topN} families in the number of transactions", f"Top {topN} families in the payment sum in BTC", f"Top {topN} families in the payment sum in USD"]
family_groups = [top_families_count, top_families_btc, top_families_usd]

for i, family_names in enumerate(family_groups):
    ax = axes[i]
    metric = metrics[i]
    title = titles[i]

    for j, family_name in enumerate(family_names):
        ax.plot(families[family_name]["month"], families[family_name][metric], color=colours[j], marker='o', markersize=7, label=family_name, alpha=0.7)

    ax.xaxis.set_major_formatter(md.DateFormatter(dateformat))
    ax.xaxis.set_major_locator(datelocator)
    ax.tick_params(labelrotation=25)
    ax.set_xlim(min_month, max_month + datetime.timedelta(days=10))
    ax.set_yscale(scale)

    # Increase font (credits to https://stackoverflow.com/questions/3899980/how-to-change-the-font-size-on-a-matplotlib-plot)
    for item in (ax.get_xticklabels() + ax.get_yticklabels()):
        item.set_fontsize(14)

    # Credits to: https://stackoverflow.com/questions/46735745/how-to-control-scientific-notation-in-matplotlib
    ax.get_yaxis().set_major_formatter(mt.FuncFormatter(lambda x, p: format(int(x), ',')))

    ax.set_title(title, fontsize=18)
    ax.legend(ncol=num_cols_legend, fontsize=font_size_legend)
    ax.grid()


first_month = min_month.strftime("%B %Y")
last_month = max_month.strftime("%B %Y")
fig.suptitle(f"Timeline of the top {topN} ransomware families from {first_month} until {last_month}", fontsize=20)

fig.autofmt_xdate(rotation=25)
plt.gcf().set_size_inches(22, 12, forward=True)
plt.tight_layout()

#plt.savefig("timeline_top_families.png")
plt.show()
