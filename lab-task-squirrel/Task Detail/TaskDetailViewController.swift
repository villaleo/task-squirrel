//
//  TaskDetailViewController.swift
//  lab-task-squirrel
//
//  Created by Charlie Hieger on 11/15/22.
//

import UIKit
import MapKit
import PhotosUI

class TaskDetailViewController: UIViewController {
    @IBOutlet private weak var completedImageView: UIImageView!
    @IBOutlet private weak var completedLabel: UILabel!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var attachPhotoButton: UIButton!
    @IBOutlet private weak var mapView: MKMapView!
    var task: Task!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.register(
            TaskAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: TaskAnnotationView.identifier
        )
        mapView.delegate = self

        mapView.layer.cornerRadius = 12
        updateUI()
        updateMapView()
    }

    /// Configure UI for the given task
    private func updateUI() {
        titleLabel.text = task.title
        descriptionLabel.text = task.description
        let completedImage = UIImage(systemName: task.isComplete ? "circle.inset.filled" : "circle")

        // calling `withRenderingMode(.alwaysTemplate)` on an image allows for coloring the image via it's `tintColor` property.
        completedImageView.image = completedImage?.withRenderingMode(.alwaysTemplate)
        completedLabel.text = task.isComplete ? "Complete" : "Incomplete"

        let color: UIColor = task.isComplete ? .systemBlue : .tertiaryLabel
        completedImageView.tintColor = color
        completedLabel.textColor = color

        mapView.isHidden = !task.isComplete
        attachPhotoButton.isHidden = task.isComplete
    }

    @IBAction func didTapAttachPhotoButton(_ sender: Any) {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            presentImagePicker()
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite, handler: { [weak self] status in
            switch status {
            case .authorized:
                DispatchQueue.main.async {
                    self?.presentImagePicker()
                }
            default:
                DispatchQueue.main.async {
                    self?.presentGoToSettingsAlert()
                }
            }
        })
    }

    func updateMapView() {
        guard let imageLocation = task.imageLocation else { return }
        let coordinate = imageLocation.coordinate
        let delta: CLLocationDegrees = 0.01
        let region: MKCoordinateRegion = .init(
            center: coordinate,
            span: .init(latitudeDelta: delta, longitudeDelta: delta)
        )
        mapView.setRegion(region, animated: true)
        
        let annotation: MKPointAnnotation = .init()
        annotation.coordinate = coordinate
        annotation.title = task.title
        mapView.addAnnotation(annotation)
    }
}

// MARK: Helper methods to present various alerts
extension TaskDetailViewController {
    /// Presents an alert notifying user of photo library access requirement with an option to go to Settings in order to update status.
    func presentGoToSettingsAlert() {
        let alertController = UIAlertController (
            title: "Photo Access Required",
            message: "In order to post a photo to complete a task, we need access to your photo library. You can allow access in Settings",
            preferredStyle: .alert)

        let settingsAction = UIAlertAction(title: "Settings", style: .default) { _ in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }

            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
            }
        }

        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    /// Show an alert for the given error
    private func showAlert(for error: Error? = nil) {
        let alertController = UIAlertController(
            title: "Oops...",
            message: "\(error?.localizedDescription ?? "Please try again...")",
            preferredStyle: .alert)

        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)

        present(alertController, animated: true)
    }
}

// MARK: Conform TaskDetailViewController to PHPickerViewControllerDelegate
extension TaskDetailViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        let result = results.first
        
        guard let assetID = result?.assetIdentifier, let location = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        ).firstObject?.location else {
            return
        }
        guard let provider = result?.itemProvider,
            provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        
        provider.loadObject(ofClass: UIImage.self, completionHandler: { [weak self] object, error in
            if let error = error {
                DispatchQueue.main.async { [weak self] in self?.showAlert(for: error) }
            }
            guard let image = object as? UIImage else { return }
            
            // UI updates should be done on main thread
            DispatchQueue.main.async {
                self?.task.set(image, with: location)
                self?.updateUI()
                self?.updateMapView()
            }
        })
    }
    
    private func presentImagePicker() {
        var configuration: PHPickerConfiguration = .init(photoLibrary: PHPhotoLibrary.shared())
        configuration.filter = .images
        configuration.preferredAssetRepresentationMode = .current
        configuration.selectionLimit = 1
        let picker: PHPickerViewController = .init(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension TaskDetailViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: TaskAnnotationView.identifier,
            for: annotation
        ) as? TaskAnnotationView else {
            fatalError("Unable to deque TaskAnnotationView")
        }
        
        annotationView.configure(with: task.image)
        return annotationView
    }
}
