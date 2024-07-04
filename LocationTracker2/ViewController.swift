import UIKit
import CoreLocation
import MapKit
import UserNotifications

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let locationManager = CLLocationManager()
    var mapView: MKMapView!
    var saveLocationButton: UIButton!
    var distanceLabel: UILabel!
    var currentLocationLabel: UILabel!
    var savedLocationLabel: UILabel!
    var savedLocation: CLLocation?
    var savedAddress: String?
    var destinationAnnotation: MKPointAnnotation?
    var currentLocationAnnotation: MKPointAnnotation?
    var selectedCoordinate: CLLocationCoordinate2D?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMapView()
        setupSaveLocationButton()
        setupLabels()
        setupLocationManager()
        requestNotificationPermissions()
        retrieveSavedLocationFromDefaults()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        showLongPressAlert()
    }
    
    func showLongPressAlert() {
        let alert = UIAlertController(title: "Select Saved Location", message: "Long press on the map to select a location for saving.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    func setupMapView() {
        mapView = MKMapView(frame: view.bounds)
        mapView.delegate = self
        view.addSubview(mapView)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(gestureRecognizer:)))
        mapView.addGestureRecognizer(longPressGesture)
    }
    
    func setupSaveLocationButton() {
        saveLocationButton = UIButton(frame: CGRect(x: 20, y: view.frame.height - 80, width: view.frame.width - 40, height: 50))
        saveLocationButton.backgroundColor = .systemBlue
        saveLocationButton.setTitle("Save Location", for: .normal)
        saveLocationButton.addTarget(self, action: #selector(saveSelectedLocation), for: .touchUpInside)
        saveLocationButton.isHidden = true
        view.addSubview(saveLocationButton)
    }
    
    func setupLabels() {
        currentLocationLabel = UILabel(frame: CGRect(x: 20, y: 100, width: view.frame.width - 40, height: 50))
        currentLocationLabel.backgroundColor = .white
        currentLocationLabel.textAlignment = .center
        currentLocationLabel.numberOfLines = 0
        currentLocationLabel.text = "Current Location:\nUnknown"
        view.addSubview(currentLocationLabel)
        
        savedLocationLabel = UILabel(frame: CGRect(x: 20, y: 170, width: view.frame.width - 40, height: 50))
        savedLocationLabel.backgroundColor = .white
        savedLocationLabel.textAlignment = .center
        savedLocationLabel.numberOfLines = 0
        savedLocationLabel.text = "Saved Location:\nUnknown"
        view.addSubview(savedLocationLabel)
        
        distanceLabel = UILabel(frame: CGRect(x: 20, y: 240, width: view.frame.width - 40, height: 100))
        distanceLabel.backgroundColor = .white
        distanceLabel.textAlignment = .center
        distanceLabel.numberOfLines = 0
        distanceLabel.text = "Distance: N/A"
        view.addSubview(distanceLabel)
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }
    
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Handle permission granted or denied
        }
    }
    
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let coordinate = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            selectedCoordinate = coordinate
            
            addDestinationAnnotation(coordinate: coordinate)
            saveLocationButton.isHidden = false
        }
    }
    
    @objc func saveSelectedLocation() {
        guard let coordinate = selectedCoordinate else { return }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        saveLocation(location: location)
        saveLocationButton.isHidden = true
    }
    
    func addDestinationAnnotation(coordinate: CLLocationCoordinate2D) {
        if let annotation = destinationAnnotation {
            mapView.removeAnnotation(annotation)
        }
        
        destinationAnnotation = MKPointAnnotation()
        destinationAnnotation?.coordinate = coordinate
        destinationAnnotation?.title = "Saved Location"
        mapView.addAnnotation(destinationAnnotation!)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        
        updateCurrentLocationAnnotation(location: currentLocation)
        updateCurrentLocationLabel(location: currentLocation)
        
        if let savedLocation = savedLocation {
            let distance = currentLocation.distance(from: savedLocation)
            updateDistanceLabel(distance: distance)
            if distance <= 10 {
                notifyArrival()
                showArrivalAlert()
            }
        }
    }
    
    func saveLocation(location: CLLocation) {
        savedLocation = location
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            if let error = error {
                print("Reverse geocoding failed: \(error.localizedDescription)")
                return
            }
            
            guard let placemark = placemarks?.first else { return }
            self?.savedAddress = self?.formatAddress(from: placemark)
            
            if let location = self?.savedLocation, let address = self?.savedAddress {
                self?.saveLocationToDefaults(location: location, address: address)
                print("Saved Location: \(address) (\(location.coordinate.latitude), \(location.coordinate.longitude))")
                
                if let currentLocation = self?.locationManager.location {
                    let distance = currentLocation.distance(from: location)
                    self?.updateDistanceLabel(distance: distance)
                    self?.updateSavedLocationLabel(address: address)
                }
            }
        }
    }
    
    func formatAddress(from placemark: CLPlacemark) -> String {
        var address = ""
        if let name = placemark.name {
            address += name + ", "
        }
        if let locality = placemark.locality {
            address += locality + ", "
        }
        if let administrativeArea = placemark.administrativeArea {
            address += administrativeArea + ", "
        }
        if let postalCode = placemark.postalCode {
            address += postalCode + ", "
        }
        if let country = placemark.country {
            address += country
        }
        return address
    }
    
    func saveLocationToDefaults(location: CLLocation, address: String) {
        let defaults = UserDefaults.standard
        defaults.set(location.coordinate.latitude, forKey: "savedLatitude")
        defaults.set(location.coordinate.longitude, forKey: "savedLongitude")
        defaults.set(address, forKey: "savedAddress")
    }
    
    func retrieveSavedLocationFromDefaults() {
        let defaults = UserDefaults.standard
        let latitude = defaults.double(forKey: "savedLatitude")
        let longitude = defaults.double(forKey: "savedLongitude")
        savedAddress = defaults.string(forKey: "savedAddress")
        
        if latitude != 0 && longitude != 0 {
            savedLocation = CLLocation(latitude: latitude, longitude: longitude)
            addDestinationAnnotation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
            
            if let currentLocation = locationManager.location {
                let distance = currentLocation.distance(from: savedLocation!)
                updateDistanceLabel(distance: distance)
                updateSavedLocationLabel(address: savedAddress ?? "Unknown")
            }
        }
    }
    
    func updateCurrentLocationAnnotation(location: CLLocation) {
        if currentLocationAnnotation == nil {
            currentLocationAnnotation = MKPointAnnotation()
            currentLocationAnnotation?.title = "Current Location"
            mapView.addAnnotation(currentLocationAnnotation!)
        }
        
        currentLocationAnnotation?.coordinate = location.coordinate
        mapView.setCenter(location.coordinate, animated: true)
    }
    
    func updateCurrentLocationLabel(location: CLLocation) {
        currentLocationLabel.text = "Current Location:\n\(formatCoordinate(location: location))"
    }
    
    func updateSavedLocationLabel(address: String) {
        savedLocationLabel.text = "Saved Location:\n\(address)"
    }
    
    func updateDistanceLabel(distance: CLLocationDistance) {
        var distanceLabelText = "Distance: N/A"
        if let savedAddress = savedAddress {
            distanceLabelText = "Distance: \(String(format: "%.2f meters", distance))\n\(savedAddress)"
        }
        distanceLabel.text = distanceLabelText
    }
    
    func formatCoordinate(location: CLLocation) -> String {
        return String(format: "Lat: %.6f, Lon: %.6f", location.coordinate.latitude, location.coordinate.longitude)
    }
    
    func notifyArrival() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "You've arrived!"
        content.body = "You are within 10 meters of your saved location."
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "ArrivalNotification", content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if let error = error {
                print("Failed to add notification request: \(error.localizedDescription)")
            } else {
                print("Notification request added successfully.")
            }
        }
    }
    func showArrivalAlert() {
        let alert = UIAlertController(title: "Arrived!", message: "You are within 10 meters of your saved location.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
