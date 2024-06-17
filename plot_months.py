#!/usr/bin/env python
#
# This script plots the timeline of ransom transactions per month, based on the file timeline_month.csv.
# In order to get the file, run the script run_stats.sh.

import datetime
import sys

import matplotlib.dates as md
import matplotlib.pyplot as plt
import matplotlib.ticker as mt


# The file is assumed to be comma-separated (i.e. in the csv format)
file_separator = ","
if len(sys.argv) != 2:
    print(f"Usage: python {sys.argv[0]} timeline_months.csv\n\n       Run run_stats.sh to get timeline_months.csv file")
    exit(1)


formatter = mt.ScalarFormatter()
formatter.set_scientific(False)

dateformat = "%Y-%m"
datelocator = md.MonthLocator(interval=3)
scale = "linear"
usd_factor = 1000000  # Show USD timeline in million USD

months, count, amount_btc, amount_usd = [], [], [], []
with open(sys.argv[1], "r") as file:
    for line in file.readlines()[1:]:  # Skip the header
        parts = line.split(file_separator)
        months.append(datetime.datetime.strptime(parts[0], dateformat))
        count.append(int(parts[1]))
        amount_btc.append(round(float(parts[2]), 4))
        amount_usd.append(round(float(parts[3]) / usd_factor, 2))


fig, axes = plt.subplots(3)

titles = ["Number of transactions", "Payment sum in BTC", "Payment sum in USD (in millions)"]
stats = [count, amount_btc, amount_usd]
colours = ["blue", "green", "red"]
epsilons = [75, 300, 1.6]

for i in range(len(stats)):
    ax = axes[i]
    y_values = stats[i]

    ax.xaxis.set_major_formatter(md.DateFormatter(dateformat))
    ax.xaxis.set_major_locator(datelocator)
    ax.set_xlim(months[0], months[-1])

    ax.yaxis.set_major_formatter(formatter)
    ax.tick_params(axis='y', labelrotation=25)
    ax.set_yscale(scale)

    # Add value labels for peaks
    epsilon = epsilons[i]
    for j in range(1, len(y_values) - 1):
        if y_values[j] > (y_values[j-1] + epsilon) and y_values[j] > (y_values[j+1] + epsilon):
            ax.text(months[j], y_values[j], y_values[j], ha="center", va="bottom", fontfamily="monospace", fontsize=14)
    ax.text(months[0], y_values[0], y_values[0], ha="left", va="bottom", fontfamily="monospace", fontsize=14)
    ax.text(months[-1], y_values[-1], y_values[-1], ha="right", va="bottom", fontfamily="monospace", fontsize=14)

    # Increase font (credits to https://stackoverflow.com/questions/3899980/how-to-change-the-font-size-on-a-matplotlib-plot)
    for item in (ax.get_xticklabels() + ax.get_yticklabels()):
        item.set_fontsize(14)

    # Credits to: https://stackoverflow.com/questions/46735745/how-to-control-scientific-notation-in-matplotlib
    ax.get_yaxis().set_major_formatter(mt.FuncFormatter(lambda x, p: format(int(x), ',')))

    ax.plot(months, y_values, color=colours[i], marker='o')
    ax.set_title(titles[i], fontsize=18)
    ax.grid()


first_month = months[0].strftime("%B %Y")
last_month = months[-1].strftime("%B %Y")
fig.suptitle(f"Timeline of ransom transactions per month in the period from {first_month} until {last_month}", fontsize=20)

fig.autofmt_xdate(rotation=25)
plt.gcf().set_size_inches(22, 12, forward=True)
plt.tight_layout()

# plt.savefig("timeline_months.png")
plt.show()
