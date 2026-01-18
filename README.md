# 🚔 zcs-community-service (QBox Version)

### A modern, highly optimized FiveM script for assigning community service tasks as an alternative to jail time. Optimized for QBox Framework.

---

## 🌟 Features
✅ **QBox Integrated:** Native support for QBox Framework and CitizenID.  
✅ **Ox Support:** Built with `ox_lib`, `ox_target`, and `ox_inventory` for maximum efficiency.  
✅ **Service Persistence:** Service state is saved in the database. Players will resume their tasks automatically after rejoining or script restarts.  
✅ **Localized Tasks:** All task labels and progress bars are fully translatable via `locales.lua`. Supports English and Finnish.  
✅ **Task System:** Multiple interactive tasks (Sweeping, Weeding, Scrubbing, Trash Picking) with custom animations and props.  
✅ **Smart Security:** Built-in protection against event spamming, teleportation, and position spoofing.  
✅ **Discord Logging:** Detailed webhooks for assignments, completions, and suspicious activity.  
✅ **Inventory Storage:** Automatic confiscation and recovery of belongings.  
✅ **Optimized Codebase:** Combined threads and `.await` based database calls for minimal overhead (~0.00ms idle).

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
- Import the `install.sql` file into your database to set up community service tracking tables.

### 4️⃣ Configure Settings
- Open `shared/config.lua` and customize:
  - `Locale = 'en'` (Choose language: `'en'` or `'fi'`)
  - `PoliceJobName = 'police'` 
  - `MinimumPoliceGrade = 0`
  - `ProgressDuration = 10000`
  - `TaskCooldown = 5000` (Security measure between tasks)

### 5️⃣ Configure Discord Logs (Optional)
- Open `server/discord_logs.lua` and set up your Discord Webhook URL.

---

## 📌 Requirements
- **Framework:** [QBox](https://github.com/Qbox-project/qbx_core)
- **Dependencies:**
  - [`ox_lib`](https://github.com/overextended/ox_lib)
  - [`ox_target`](https://github.com/overextended/ox_target)
  - [`ox_inventory`](https://github.com/overextended/ox_inventory)
  - [`oxmysql`](https://github.com/overextended/oxmysql)

---

## 🎮 How to Use

### 👮 Assigning Community Service
- Police officers can assign community service using the command:
  1. **Command:** `/cs` or `/communityservice`.
  2. **Menu:** Choose an online player and specify the amount of tasks.

### 🧹 Completing Tasks
- Players are teleported to the service area and must complete tasks using target interaction points.
- A Text UI displays remaining tasks at the top of the screen.
- After all tasks are completed, the player is automatically released and teleported back.

### 🎒 Retrieving Belongings
- After release, players can visit the **Retrieval Point** (marked on the map) to reclaim their items.

---

## ⚙️ Configuration

### 🌍 Localization
- All text strings are located in `shared/locales.lua`.

### 📍 Task & Service Locations
- Positions for the service area, release point, and individual task spots are in `shared/locations.lua`.

---

## 📜 License
This project is licensed under the **MIT License**.

---

## 💡 Credits
Developed and optimized by **ZoniBoy00**. Remastered for the QBox Ecosystem.

🚀 **Enhance your roleplay experience with a modern community service system!**
