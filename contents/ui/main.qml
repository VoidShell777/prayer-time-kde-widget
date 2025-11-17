import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.notification

PlasmoidItem {
    id: root
    
    preferredRepresentation: compactRepresentation
    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {}
    
    property var prayerTimes: ({})
    property string nextPrayer: ""
    property string nextPrayerTime: ""
    property int secondsUntilNext: 0
    property bool notificationShown: false
    property bool locationFetched: false
    
    property string apiService: Plasmoid.configuration.apiService || "aladhan"
    property string city: Plasmoid.configuration.city || ""
    property string country: Plasmoid.configuration.country || ""
    property double latitude: Plasmoid.configuration.latitude || 0
    property double longitude: Plasmoid.configuration.longitude || 0
    property int calculationMethod: Plasmoid.configuration.calculationMethod || 3
    property int notificationMinutes: Plasmoid.configuration.notificationMinutes || 15
    property bool useArabic: Plasmoid.configuration.useArabic || false
    
    property var arabicPrayerNames: {
        "Fajr": "الفجر",
        "Dhuhr": "الظهر",
        "Asr": "العصر",
        "Maghrib": "المغرب",
        "Isha": "العشاء"
    }
    
    Timer {
        id: updateTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            updateCountdown()
            checkNotification()
        }
    }
    
    Timer {
        id: fetchTimer
        interval: 3600000 // check every 1 heur
        running: true
        repeat: true
        onTriggered: checkAndFetchPrayerTimes()
    }
    
    Component.onCompleted: {
        // Try to auto get location if not set
        if (latitude === 0 && longitude === 0) {
            fetchLocation()
        } else {
            fetchPrayerTimes()
        }
    }
    
    function fetchLocation() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://ipapi.co/json/")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.latitude && response.longitude) {
                        latitude = response.latitude
                        longitude = response.longitude
                        city = response.city || ""
                        country = response.country_name || ""
                        
                        // Save to config
                        Plasmoid.configuration.latitude = latitude
                        Plasmoid.configuration.longitude = longitude
                        Plasmoid.configuration.city = city
                        Plasmoid.configuration.country = country
                        
                        locationFetched = true
                        fetchPrayerTimes()
                    }
                }
            }
        }
        xhr.send()
    }
    
    function checkAndFetchPrayerTimes() {
        var now = new Date()
        var lastFetchDate = new Date(Plasmoid.configuration.lastFetchDate || 0)
        
        // fetching if its a new day 
        if (now.getDate() !== lastFetchDate.getDate() || 
            now.getMonth() !== lastFetchDate.getMonth() ||
            now.getFullYear() !== lastFetchDate.getFullYear()) {
            fetchPrayerTimes()
        }
    }
    
    function fetchPrayerTimes() {
        if (latitude === 0 && longitude === 0) {
            console.log("Location not set, cannot fetch prayer times")
            return
        }
        
        if (apiService === "aladhan") {
            fetchFromAladhan()
        } else {
            fetchFromSalahHour()
        }
        
        // save fetch date (checkpoint)
        Plasmoid.configuration.lastFetchDate = new Date().toString()
    }
    
    function fetchFromAladhan() {
        var xhr = new XMLHttpRequest()
        var date = new Date()
        var timestamp = Math.floor(date.getTime() / 1000)
        
        // uuse coordinates for more precised times
        var url = "http://api.aladhan.com/v1/timings/" + timestamp + 
                  "?latitude=" + latitude + 
                  "&longitude=" + longitude + 
                  "&method=" + calculationMethod
        
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.data && response.data.timings) {
                        parsePrayerTimes(response.data.timings)
                    }
                } else {
                    console.log("Failed to fetch prayer times from Al-Adhan")
                }
            }
        }
        xhr.send()
    }
    
    function fetchFromSalahHour() {
        var xhr = new XMLHttpRequest()
        var date = new Date()
        var dateStr = date.getFullYear() + "-" + 
                      String(date.getMonth() + 1).padStart(2, '0') + "-" + 
                      String(date.getDate()).padStart(2, '0')
        
        var url = "https://api.salahhour.com/v1/prayer-times?lat=" + latitude + 
                  "&lng=" + longitude + 
                  "&date=" + dateStr + 
                  "&method=" + calculationMethod
        
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText)
                    if (response.timings) {
                        parsePrayerTimes(response.timings)
                    }
                } else {
                    console.log("Failed to fetch prayer times from Salah Hour")
                }
            }
        }
        xhr.send()
    }
    
    function parsePrayerTimes(timings) {
        // extract time only (remove timezone and other info)
        prayerTimes = {
            "Fajr": extractTime(timings.Fajr),
            "Dhuhr": extractTime(timings.Dhuhr),
            "Asr": extractTime(timings.Asr),
            "Maghrib": extractTime(timings.Maghrib),
            "Isha": extractTime(timings.Isha)
        }
        
        findNextPrayer()
    }
    
    function extractTime(timeString) {
        // extract HH:MM from formats like "04:45 (EST)" or "04:45"
        if (!timeString) return "00:00"
        var match = timeString.match(/(\d{2}:\d{2})/)
        return match ? match[1] : timeString.substring(0, 5)
    }
    
    function findNextPrayer() {
        var now = new Date()
        var currentMinutes = now.getHours() * 60 + now.getMinutes()
        
        var prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
        
        for (var i = 0; i < prayers.length; i++) {
            var prayer = prayers[i]
            var time = prayerTimes[prayer]
            if (!time) continue
            
            var parts = time.split(":")
            var prayerMinutes = parseInt(parts[0]) * 60 + parseInt(parts[1])
            
            if (prayerMinutes > currentMinutes) {
                nextPrayer = prayer
                nextPrayerTime = time
                updateCountdown()
                return
            }
        }
        
        // if no prayers left today, next is Fajr tomorrow
        nextPrayer = "Fajr"
        nextPrayerTime = prayerTimes.Fajr || "00:00"
        updateCountdown()
    }
    
    function updateCountdown() {
        if (!nextPrayerTime) return
        
        var now = new Date()
        var parts = nextPrayerTime.split(":")
        var prayerTime = new Date()
        prayerTime.setHours(parseInt(parts[0]))
        prayerTime.setMinutes(parseInt(parts[1]))
        prayerTime.setSeconds(0)
        prayerTime.setMilliseconds(0)
        
        if (prayerTime <= now) {
            prayerTime.setDate(prayerTime.getDate() + 1)
        }
        
        var diff = Math.floor((prayerTime - now) / 1000)
        
        if (diff <= 0) {
            findNextPrayer()
            notificationShown = false
        } else {
            secondsUntilNext = diff
        }
    }
    
    function checkNotification() {
        var minutesUntil = Math.floor(secondsUntilNext / 60)
        
        if (minutesUntil <= notificationMinutes && minutesUntil > 0 && !notificationShown) {
            notificationShown = true
            showNotification(nextPrayer, minutesUntil)
        }
        
        // reeset notification flag when prayer time passes
        if (minutesUntil === 0) {
            notificationShown = false
        }
    }
    
    function showNotification(prayer, minutes) {
        var prayerName = useArabic ? arabicPrayerNames[prayer] : prayer
        var message = useArabic ? 
            "حان وقت صلاة " + prayerName + " بعد " + minutes + " دقيقة" :
            prayer + " prayer in " + minutes + " minute" + (minutes > 1 ? "s" : "")
        
        console.log("Prayer notification: " + message)
    }
    
    function formatCountdown(seconds) {
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        var secs = seconds % 60
        
        if (hours > 0) {
            return hours + "h " + minutes + "m"
        } else {
            return minutes + "m " + secs + "s"
        }
    }
    
    function getPrayerName(prayer) {
        return useArabic ? arabicPrayerNames[prayer] : prayer
    }
}