import SwiftUI
import CoreData
import PhotosUI

struct AddEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // nil = adding a new entry, non-nil = editing this entry
    let entry: CraftEntry?

    @State private var title: String
    @State private var craftType: String
    @State private var location: String
    @State private var notes: String
    @State private var image: UIImage?
    @State private var showingCamera = false
    @State private var selectedItem: PhotosPickerItem?

    init(entry: CraftEntry? = nil) {
        self.entry = entry
        _title = State(initialValue: entry?.title ?? "")
        _craftType = State(initialValue: entry?.craftType ?? crafts[0])
        _location = State(initialValue: entry?.location ?? "")
        _notes = State(initialValue: entry?.notes ?? "")
        _image = State(initialValue: entry?.photo.flatMap { UIImage(data: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Location found", text: $location)
                TextField("Notes", text: $notes, axis: .vertical)
                Picker("Craft", selection: $craftType) {
                    ForEach(crafts, id: \.self) { craft in
                        Text(craft)
                    }
                }
                Section("Photo") {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                    }

                    Button("Take Photo") {
                        showingCamera = true
                    }
                    .disabled(
                        !UIImagePickerController.isSourceTypeAvailable(.camera)
                    )

                    PhotosPicker(
                        "Choose from Library",
                        selection: $selectedItem,
                        matching: .images
                    )
                }
            }
            .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = uiImage
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(image: $image)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveEntry() {
        // Reuse the existing entry when editing, otherwise create a new one
        let target = entry ?? CraftEntry(context: viewContext)

        if entry == nil {
            target.id = UUID()
            target.date = Date()
        }

        target.title = title
        target.location = location
        target.notes = notes
        target.craftType = craftType
        target.photo = image?.jpegData(compressionQuality: 0.7)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Could not save: \(error)")
        }
    }
}
