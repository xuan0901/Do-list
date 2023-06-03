import SwiftUI
import CoreLocation
import MapKit


struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var creationDate: Date
    var dueDate: Date
    var location: String
}

class TodoManager: ObservableObject {
    @Published var todoItems: [TodoItem] = []
    
    init() {
        loadTodoItems()
    }
    
    func loadTodoItems() {
        // Load todoItems from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "TodoItems") {
            if let decodedItems = try? JSONDecoder().decode([TodoItem].self, from: data) {
                todoItems = decodedItems
            }
        }
    }
    
    func saveTodoItems() {
        // Save todoItems to UserDefaults
        if let encodedData = try? JSONEncoder().encode(todoItems) {
            UserDefaults.standard.set(encodedData, forKey: "TodoItems")
        }
    }
    
    func addTodoItem(title: String, description: String, dueDate: Date, location: String) {
        let newItem = TodoItem(title: title, description: description, creationDate: Date(), dueDate: dueDate, location: location)
        todoItems.append(newItem)
        saveTodoItems()
    }
    
    func updateTodoItem(_ item: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
            todoItems[index] = item
            saveTodoItems()
        }
    }
    
    func deleteTodoItem(_ item: TodoItem) {
        if let index = todoItems.firstIndex(where: { $0.id == item.id }) {
            todoItems.remove(at: index)
            saveTodoItems()
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location update failed with error: \(error.localizedDescription)")
    }
}

struct ContentView: View {
    @StateObject private var todoManager = TodoManager()
    @State private var showingAddSheet = false
    @State private var selectedItem: TodoItem?
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(todoManager.todoItems.sorted(by: { $0.dueDate > $1.dueDate })) { item in
                    Button(action: {
                        selectedItem = item
                    }) {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.headline)
                            Text(item.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Due Date: \(formatDate(item.dueDate))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            deleteItem(item)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Todo List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEditView(todoManager: todoManager, locationManager: locationManager)
            }
            .sheet(item: $selectedItem) { item in
                AddEditView(todoManager: todoManager, locationManager: locationManager, selectedItem: item)
            }
        }
    }
    


    

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    func deleteItem(_ item: TodoItem) {
        todoManager.deleteTodoItem(item)
    }
}


struct AddEditView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var todoManager: TodoManager
    @ObservedObject var locationManager: LocationManager
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var location = ""
    var selectedItem: TodoItem?
    
    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("Enter title", text: $title)
            }
            
            Section(header: Text("Description")) {
                TextField("Enter description", text: $description)
            }
            
            Section(header: Text("Due Date")) {
                DatePicker(selection: $dueDate, in: Date()..., displayedComponents: [.date, .hourAndMinute]) {
                    Text("Select due date")
                }
            }
            
            Section(header: Text("Location")) {
                HStack {
                    Text(locationManager.currentLocation != nil ? "Current Location: \(locationManager.currentLocation!.coordinate.latitude), \(locationManager.currentLocation!.coordinate.longitude)" : "Location not available")
                    Spacer()
                    Button(action: {
                        location = locationManager.currentLocation != nil ? "\(locationManager.currentLocation!.coordinate.latitude), \(locationManager.currentLocation!.coordinate.longitude)" : ""
                    }) {
                        Text("Get Current Location")
                    }
                    .disabled(locationManager.currentLocation == nil)
                }
                
                TextField("Enter location", text: $location)
            }
            
            Section {
                Button(action: {
                    saveItem()
                }) {
                    Text(selectedItem == nil ? "Add Item" : "Update Item")
                }
                .disabled(title.isEmpty)
            }
        }
        .navigationTitle(selectedItem == nil ? "Add Item" : "Edit Item")
        .onAppear {
            if let item = selectedItem {
                title = item.title
                description = item.description
                dueDate = item.dueDate
                location = item.location
            }
            
            if let currentLocation = locationManager.currentLocation {
                location = "\(currentLocation.coordinate.latitude), \(currentLocation.coordinate.longitude)"
            }
        }
    }
    
    func saveItem() {
        if let item = selectedItem {
            let updatedItem = TodoItem(id: item.id, title: title, description: description, creationDate: item.creationDate, dueDate: dueDate, location: location)
            todoManager.updateTodoItem(updatedItem)
        } else {
            todoManager.addTodoItem(title: title, description: description, dueDate: dueDate, location: location)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
