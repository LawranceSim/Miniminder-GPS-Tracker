# Miniminder-GPS-Tracker 📍

**Miniminder** is a high-precision, real-time GPS tracking application developed as part of the **MyNext Innovate** competition, where it achieved a **National Top 20** ranking. This project demonstrates the integration of mechanical engineering logic with modern mobile development to solve real-world geospatial challenges.

## 🚀 Technical Highlights

### 1. Core Engine: Haversine Distance Calculation

Rather than relying solely on third-party API distance outputs, this project implements a custom mathematical model based on the **Haversine Formula**. This calculates the shortest distance (great-circle distance) between two points on a sphere, ensuring centimeter-level precision for distance monitoring between the user and the tracker.

### 2. Enterprise-Grade Security (Secrets Management)

To protect developer privacy and Google Maps API quotas, the project follows industry-standard **Secrets Management** practices:

* **Dynamic Injection**: Sensitive API keys are isolated in `android/local.properties` (excluded from version control) and dynamically injected into the `AndroidManifest.xml` via Gradle **Manifest Placeholders** during the build process.
* **Environment Decoupling**: The source code provides a `consts.dart.example` template, ensuring that real credentials never leak into the Git history.

### 3. Optimized Real-time UI Rendering

The application utilizes Flutter’s **Stream** mechanism to listen for high-frequency location updates. The logic is optimized to handle rapid data flow efficiently, preventing redundant UI re-renders and ensuring smooth movement of markers and polylines on the map.

## 🛠️ Tech Stack

* **Framework**: Flutter (Dart)
* **Maps**: Google Maps SDK for Android
* **Backend Emulation**: Mocky.io for simulated tracker telemetry payloads
* **Version Control**: Git with custom security configurations.

## 📦 Setup & Installation

1. **Clone the Repository**:
```bash
git clone https://github.com/LawranceSim/Miniminder-GPS-Tracker.git

```


2. **Configure API Keys**:
* Create a `local.properties` file in the `android/` directory.
* Add the following line: `MAPS_API_KEY=YOUR_ACTUAL_API_KEY`.
* Create `lib/consts.dart` based on the provided `consts.dart.example` template.


3. **Run the Application**:
```bash
flutter pub get
flutter run

```
