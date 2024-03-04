import SwiftUI
import CoreML
import PhotosUI

// ProbabilityListView için kod
struct ProbabilityListView: View {
    let probs: [Dictionary<String, Double>.Element]
    
    var body: some View {
        List(probs, id: \.key) { prob in
            HStack {
                Text(prob.key)
                Text("\(prob.value as NSNumber, formatter: NumberFormatter.percentFormatter)")
            }
        }
    }
}

// NumberFormatter extension
extension NumberFormatter {
    static var percentFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter
    }
}

// ImagePicker için kod
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}

// UIImage extension for resizing and converting to CVPixelBuffer
extension UIImage {
    func resizeTo(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, self.scale)
        draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    func toCVPixelBuffer() -> CVPixelBuffer? {
        let width = Int(size.width)
        let height = Int(size.height)
        
        var pixelBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let context = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(context, [])
        let pixelData = CVPixelBufferGetBaseAddress(context)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapContext = CGContext(data: pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(context), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        guard let drawingContext = bitmapContext else {
            return nil
        }
        
        drawingContext.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        CVPixelBufferUnlockBaseAddress(context, [])
        
        return context
    }
}

// ContentView için kod
@available(iOS 17.0, *)
struct ContentView: View {
    let model = try! SkinCancerV2()
    @State private var probs: [String: Double] = [:]
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var uiImage: UIImage? = nil
    @State private var isCameraSelected: Bool = false
    
    var sortedProbs: [Dictionary<String, Double>.Element] {
        return probs.sorted { $0.value > $1.value }
    }
    
    var body: some View {
        VStack {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
            }
            
            HStack {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("Resim Seçin")
                }
                
                Button("Kamera") {
                    isCameraSelected = true
                }
                .buttonStyle(.bordered)
            }
            
            Button("Tahmin Et") {
                guard let resizedImage = uiImage?.resizeTo(to: CGSize(width: 299, height: 299)),
                      let buffer = resizedImage.toCVPixelBuffer() else {
                    return
                }
                
                do {
                    let result = try model.prediction(image: buffer)
                    probs = result.targetProbability
                } catch {
                    print(error.localizedDescription)
                }
            }
            .buttonStyle(.borderedProminent)
            
            ProbabilityListView(probs: sortedProbs)
        }
        .onChange(of: selectedPhotoItem) { newItem in
            newItem?.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data, let image = UIImage(data: data) {
                        uiImage = image
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
        }
        .sheet(isPresented: $isCameraSelected) {
            ImagePicker(image: $uiImage, sourceType: .camera)
        }
        .padding()
        .background(Color.cyan)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 17.0, *) {
            ContentView()
        } else {
            // Fallback on earlier versions
        }
    }
}
