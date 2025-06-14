/* eslint-disable max-len */
process.env.FIREBASE_FUNCTIONS_USE_HTTP = "true";
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");
const {DateTime} = require("luxon");
require("dotenv").config(); // Load from .env if present

admin.initializeApp();

// eslint-disable-next-line require-jsdoc
async function checkTides() {
  const apiKey = process.env.WORLDTIDES_API_KEY;

  if (!apiKey) {
    throw new Error("Missing WorldTides API key.");
  }

  const beach = {
    name: "New Break",
    lat: 32.7503,
    lon: -117.2550,
    thresholdFt: 1.5,
  };

  let sunriseDate;
  let sunsetDate;
  let sunriseStr;
  let sunsetStr;
  try {
    const sunApiUrl = `https://api.sunrisesunset.io/json?lat=${beach.lat}&lng=${beach.lon}&tzid=America/Los_Angeles`;
    console.log(`☀️ Fetching sunrise/sunset data from: ${sunApiUrl}`);
    const sunResponse = await axios.get(sunApiUrl);

    if (sunResponse.data && sunResponse.data.results) {
      const results = sunResponse.data.results;
      sunriseStr = results.sunrise;
      sunsetStr = results.sunset;
      console.log(`☀️ Sunrise/Sunset API Response: Sunrise=${sunriseStr}, Sunset=${sunsetStr}, FirstLight=${results.first_light}, LastLight=${results.last_light}`);

      // Helper function to parse "h:mm:ss AM/PM" times for today in Los Angeles
      const parseTimeForToday = (timeString) => {
        // Get today's date in LA timezone
        const now = new Date();
        const laDate = new Date(now.toLocaleString("en-US", {timeZone: "America/Los_Angeles"}));
        const [month, day, year] = [laDate.getMonth(), laDate.getDate(), laDate.getFullYear()];

        // Parse the time string directly since it's already in correct format from API
        const [time, period] = timeString.split(" ");
        const [hours, minutes, seconds] = time.split(":").map(Number);

        // Create date using the parsed components
        const result = new Date();
        result.setFullYear(year);
        result.setMonth(month);
        result.setDate(day);
        result.setHours(
          period.toUpperCase() === "PM" && hours !== 12 ? hours + 12 :
          period.toUpperCase() === "AM" && hours === 12 ? 0 : hours,
          minutes,
          seconds,
          0,
        );
        return result;
      };

      try {
        sunriseDate = parseTimeForToday(results.sunrise);
        sunsetDate = parseTimeForToday(results.sunset);

        if (isNaN(sunriseDate.getTime()) || isNaN(sunsetDate.getTime())) {
          console.error("❌ Invalid date constructed from parsed sunrise/sunset API times:", results.sunrise, results.sunset);
        } else {
          console.log(`🌅 Sunrise: ${sunriseDate.toLocaleString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            second: "2-digit",
          })}`);
          console.log(`🌇 Sunset: ${sunsetDate.toLocaleString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            second: "2-digit",
          })}`);
        }
      } catch (parseError) {
        console.error("❌ Error parsing sunrise/sunset time strings:", parseError);
        // Ensure sunriseDate and sunsetDate are undefined or null so later checks handle it
        sunriseDate = undefined;
        sunsetDate = undefined;
      }
    } else {
      console.error("❌ Sunrise/Sunset API call succeeded but response format was unexpected:", sunResponse.data);
      // Decide how to handle this: proceed without daylight check, or return.
      // For now, we'll log and proceed, meaning the daylight check might not be applied.
    }
  } catch (sunError) {
    console.error("❌ Error fetching sunrise/sunset data:", sunError.message);
    // If we can't get sunrise/sunset, we can't reliably check for daylight.
    // You might choose to return here, or proceed without the daylight check.
    // For this implementation, we'll log the error and proceed, which means
    // the notification might be sent even if we couldn't verify daylight.
    // Alternatively, to strictly enforce the daylight rule:
    // return;
  }

  try {
    const tideApiUrl = `https://www.worldtides.info/api/v3?heights&date=today&days=1&datum=CD&step=600&lat=${beach.lat}&lon=${beach.lon}&key=${apiKey}`;
    console.log(`🌊 Fetching tide data from: ${tideApiUrl}`);
    const response = await axios.get(tideApiUrl);

    const data = response.data.heights || [];
    // console.log("🌊 Raw tide data (UTC):"); // Optional: keep for debugging if needed
    // data.forEach((d) => {
    //   console.log(` - ${new Date(d.dt * 1000).toISOString()} | ${d.height.toFixed(2)}m`);
    // });

    console.log(`📊 Retrieved ${data.length} tide entries for ${beach.name}`);

    const lowTideWindows = [];
    let currentWindow = {start: null, end: null};
    let prevBelow = false;

    // Find all low tide windows
    for (const entry of data) {
      const heightFt = entry.height * 3.28084; // Convert meters to feet
      const entryTime = new Date(entry.dt * 1000);
      const entryTimeFormatted = entryTime.toLocaleString("en-US", {
        hour: "numeric",
        minute: "2-digit",
        second: "2-digit",
        hour12: true,
        timeZone: "America/Los_Angeles",
      });
      console.log(`🌊 Checking ${entryTimeFormatted} PST: ${heightFt.toFixed(2)} ft`);

      if (heightFt < beach.thresholdFt) {
        if (!currentWindow.start) {
          currentWindow.start = entry;
        }
        prevBelow = true;
      } else if (prevBelow) {
        currentWindow.end = entry;
        lowTideWindows.push({...currentWindow});
        currentWindow = {start: null, end: null};
        prevBelow = false;
      }
    }

    // Handle case where low tide extends to end of data
    if (prevBelow && currentWindow.start) {
      currentWindow.end = data[data.length - 1];
      lowTideWindows.push({...currentWindow});
    }

    // First check if we have valid daylight hours
    if (!sunriseDate || !sunsetDate || isNaN(sunriseDate.getTime()) || isNaN(sunsetDate.getTime())) {
      console.warn("⚠️ Could not verify daylight hours due to missing or invalid sunrise/sunset data. Notification not sent based on daylight rule.");
      return;
    }

    console.log(`☀️ Daylight hours: ${sunriseStr} to ${sunsetStr}`);

    // Check if we found any low tide windows
    if (lowTideWindows.length === 0) {
      console.log(`ℹ️ No low tide windows found for ${beach.name} today below ${beach.thresholdFt}ft threshold.`);
      return;
    }

    // Process each low tide window
    for (const window of lowTideWindows) {
      // Convert UTC timestamps to LA timezone using Luxon
      const lowTideStartLA = DateTime.fromSeconds(window.start.dt)
          .setZone("America/Los_Angeles");
      const lowTideEndLA = DateTime.fromSeconds(window.end.dt)
          .setZone("America/Los_Angeles");

      // Format times for debug logging
      const lowTideStartFormatted = lowTideStartLA.toLocaleString({
        ...DateTime.TIME_WITH_SECONDS,
        hour12: true,
      });
      const lowTideEndFormatted = lowTideEndLA.toLocaleString({
        ...DateTime.TIME_WITH_SECONDS,
        hour12: true,
      });
      console.log(`🌊 Low tide window identified: ${lowTideStartFormatted} to ${lowTideEndFormatted}`);

      // Convert sunrise/sunset strings to Luxon DateTime objects
      const sunriseLuxon = DateTime.fromFormat(sunriseStr, "h:mm:ss a", {zone: "America/Los_Angeles"});
      const sunsetLuxon = DateTime.fromFormat(sunsetStr, "h:mm:ss a", {zone: "America/Los_Angeles"});

      // Check for any overlap with daylight hours
      if (lowTideStartLA < sunsetLuxon && lowTideEndLA > sunriseLuxon) {
        // Determine if window extends beyond daylight hours
        const startsBeforeSunrise = lowTideStartLA < sunriseLuxon;
        const endsAfterSunset = lowTideEndLA > sunsetLuxon;

        // Calculate the actual beachable window
        const beachableStart = startsBeforeSunrise ? sunriseLuxon : lowTideStartLA;
        const beachableEnd = endsAfterSunset ? sunsetLuxon : lowTideEndLA;

        // Format sunrise/sunset times without seconds
        const sunriseTimeShort = sunriseLuxon.toFormat("h:mm a");
        const sunsetTimeShort = sunsetLuxon.toFormat("h:mm a");

        // Format times in LA timezone for display
        const beachableStartTimeFormatted = startsBeforeSunrise ?
          `${sunriseTimeShort} (sunrise)` :
          beachableStart.toFormat("h:mm a");
        const beachableEndTimeFormatted = endsAfterSunset ?
          `${sunsetTimeShort} (sunset)` :
          beachableEnd.toFormat("h:mm a");

        // Format the beachable window text
        const beachableWindowFormatted = `${beachableStartTimeFormatted} to ${beachableEndTimeFormatted}`;

        console.log(`✅ Beachable window during daylight: ${beachableWindowFormatted}.`);

        const message = {
          notification: {
            title: "🌊 New Break is looking good!",
            body: `Beachable from ${beachableWindowFormatted}.`,
          },
          topic: "tide-updates",
        };
        console.log(`✅ Preparing notification: ${message.notification.title} - ${message.notification.body}`);
        await admin.messaging().send(message);
        console.log(`✅ Notification sent for ${beach.name}`);
      } else {
        console.log(`ℹ️ Low tide window (${lowTideStartFormatted} to ${lowTideEndFormatted}) does not overlap with daylight hours. Notification not sent.`);
      }
    }
  } catch (error) { // This catch is for the tide API call and subsequent processing
    console.error("❌ Error fetching tide data or processing:", error);
  }
}

// Production export for scheduled use by Cloud Scheduler
exports.sendTideAlert = onSchedule(
    {
      schedule: "every day 05:00",
      timeZone: "America/Los_Angeles",
    },
    async () => {
      await checkTides();
    },
);

// Local test runner for development
if (require.main === module) {
  checkTides();
}
