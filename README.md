# TCX2CSV
Powershell module to convert the basic fitness information from TCX JSON files to CSV for import into other trackers.

I track my runs in a complex spreadsheet that performs additional calculations and monitoring that I would traditionally have to pay for with services such as SmashRun or Strava. Therefore, I created a module that allows me to take the TCX exports from those daily activities, which are simply JSON formatted files, and extracts all the basic information, such as distance, time, average and maximum heart rate and cadence. The script then calculates additional data, such as step count, which is not traditionally included in TCX exports and it then sorts and saves these to a CSV file, which I can import into my personal tracker.

Right now it's only designed to capture run data, but I may expand this, in the future.
