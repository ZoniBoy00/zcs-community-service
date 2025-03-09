# 🚔 zcs-community-service

### A FiveM script for assigning community service tasks as an alternative to jail time.

---

## 🌟 Features
✅ Assign community service tasks instead of jail time  
✅ Configurable task system with progress tracking  
✅ Supports multiple languages (English & Finnish)  
✅ Customizable task locations and durations  
✅ Discord logging for tracking player punishments  
✅ Optimized and lightweight for smooth server performance  

---

## 📥 Installation Guide

### 1️⃣ Download & Extract
- Clone this repository or download the ZIP file.
- Extract the folder and place it inside your FiveM `resources` directory.

### 2️⃣ Add to Server Config
- Open your `server.cfg` file and add:
  ```cfg
  ensure zcs-community-service
  ```

### 3️⃣ Install Database
- Import the `install.sql` file into your database to set up necessary tables.

### 4️⃣ Configure Settings
- Open `shared/config.lua` and customize the following:
  - `Debug = false` (Disable debug mode in production)
  - `EnableTestMenu = false` (Disable test menu for players)
  - `Locale = 'en'` (Choose language: `'en'` for English, `'fi'` for Finnish)
  - `PoliceJobName = 'police'` (Set your police job name)
  - `ProgressStyle = 'bar'` (Choose progress display style: `'bar'` or `'circle'`)
  - `ProgressDuration = 5000` (Task duration in milliseconds)
  - `TaskCooldown = 10000` (Cooldown between tasks in milliseconds)

### 5️⃣ Configure Discord Logs (Optional)
- Open `server/discord_logs.lua` and set up your Discord Webhook for logging player punishments.

---

## 📌 Requirements
- **Dependencies:**
  - [`ox_lib`](https://github.com/overextended/ox_lib/releases/latest)
  - [`ox_target`](https://github.com/overextended/ox_target/releases/latest)
  - [`ox_inventory`](https://github.com/overextended/ox_inventory/releases/latest)
  - [`oxmysql`](https://github.com/overextended/oxmysql/releases/latest)

---

## 🎮 How to Use

### 👮 Assigning Community Service
- Police officers can assign community service using the following method:
  1. **Command:**
     - Use the command:
       ```
       /cs
       ```
     - This opens a menu where officers can select a player and assign them to community service.

### 🧹 Completing Tasks
- Players will be sent to the community service location.
- They must complete their assigned tasks (e.g., sweeping, cleaning).
- Progress is tracked, and they will be released once all tasks are completed.

### 🎒 Retrieving Belongings
- After completing community service, players can retrieve their confiscated items at the designated retrieval point.

---

## ⚙️ Configuration

### 🌍 Localization
- Modify `shared/locales.lua` to add or edit language translations.

### 📍 Task & Service Locations
- Adjust task positions and service locations in `shared/locations.lua`.
- Customize spawn points, task areas, and retrieval zones to match your server layout.

---

## 📜 License
This project is licensed under the **MIT License**. You are free to modify and use it as you see fit. See the [LICENSE](https://github.com/ZoniBoy00/zcs-community-service/blob/main/LICENSE) file for more details.

---

## 💡 Credits
Developed by **ZoniBoy00**. Contributions & feedback are always welcome!

🚀 **Enhance your RP server with zcs-community-service today!**

