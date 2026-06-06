# GPX2CSV
Powershell module to convert the basic fitness information from GPX JSON files to CSV for import into other trackers.

I track my runs in a complex spreadsheet that performs additional calculations and monitoring that I would traditionally have to pay for with services such as SmashRun or Strava. Therefore, I created a module that allows me to take the Strava exports from those daily activities, which are simply JSON formatted files, and extracts all the basic information, such as distance, time, average and maximum heart rate and cadence. The script then calculates additional data, sorts and saves these to a CSV file, which I can import into my personal tracker.

As of January, 2026, Strava no longer supports TCX files, so I adjusted this script to work exclusively with GPX files instead, which is a wider standard, anyway. In order to use it, download a GPX file from  Strava and run this script in that directory, in order
to parse the important parts of it into a CSV file.

usage: GPX2CSV <weight in kg>

You do not need to provide a weight in KG, but if you do not, the script will use the default provided in the accompanying PSD1 file. For those of you who do not know the metric system, divide your weight in pounds (lbs) by 2.2 to get your metric equivalent in kilograms.
