import SwiftUI
import UIKit

//Folder Picker Delegate Protocol
public protocol FolderPickerDelegate: AnyObject {
    func folderPicker(_ picker: FolderPickerView, didSelectFolder url: URL)
    func folderPickerDidCancel(_ picker: FolderPickerView)
}

//Folder Picker Configuration
public struct FolderPickerConfiguration {
    public let title: String
    public let allowedRootPath: URL
    public let showCancelButton: Bool
    public let confirmButtonTitle: String

    public init(
        title: String = "Choose Folder",
        allowedRootPath: URL,
        showCancelButton: Bool = true,
        confirmButtonTitle: String = "Select"
    ) {
        self.title = title
        self.allowedRootPath = allowedRootPath
        self.showCancelButton = showCancelButton
        self.confirmButtonTitle = confirmButtonTitle
    }
}

//Folder Picker SwiftUI Main View
public struct FolderPickerView: View {

    public weak var delegate: FolderPickerDelegate?
    public let configuration: FolderPickerConfiguration

    @State private var selectedFolder: URL?
    @State private var expandedFolders: Set<URL> = []
    @State private var folderTree: [FolderNode] = []
    @State private var viewHeight: CGFloat = 400

    //Init function
    public init(
        configuration: FolderPickerConfiguration,
        delegate: FolderPickerDelegate? = nil
    ) {
        self.configuration = configuration
        self.delegate = delegate
    }

    // View's Body
    public var body: some View {
        VStack(spacing: 0) {
            //Drag handle for resizing
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            HStack {
                if configuration.showCancelButton {
                    Button("Cancel") {
                        delegate?.folderPickerDidCancel(self)
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                Text(configuration.title)
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Button(configuration.confirmButtonTitle) {
                    if let selectedFolder = selectedFolder {
                        delegate?.folderPicker(self, didSelectFolder: selectedFolder)
                    }
                }
                .foregroundColor(selectedFolder != nil ? .blue : .gray)
                .disabled(selectedFolder == nil)
            }
            .padding()

            Divider()

            //Folder Tree List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(folderTree, id: \.id) { node in
                        folderTreeRow(node)
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxHeight: viewHeight - 120) //Account for header and drag handle
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newHeight = viewHeight - value.translation.height
                    let minHeight: CGFloat = 250
                    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9
                    viewHeight = max(minHeight, min(maxHeight, newHeight))
                }
                .onEnded { _ in
                    //Ensure minimum height is maintained after drag ends
                    let minHeight: CGFloat = 250
                    let maxHeight: CGFloat = UIScreen.main.bounds.height * 0.9

                    if viewHeight < minHeight {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewHeight = minHeight
                        }
                    } else if viewHeight > maxHeight {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewHeight = maxHeight
                        }
                    }
                }
        )
        .onAppear {
            loadFolderTree()
        }
    }

    private func loadFolderTree() {
        folderTree = createFolderTree(at: configuration.allowedRootPath)
    }

    private func createFolderTree(at rootURL: URL) -> [FolderNode] {
        guard let rootNode = createChildNode(for: rootURL, level: 0) else { return [] }
        return [rootNode]
    }

    private func createChildNode(for url: URL, level: Int) -> FolderNode? {
        let fileManager = FileManager.default
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            let subfolders = contents.filter { $0.isDirectory }
                .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

            return FolderNode(
                url: url,
                level: level,
                hasSubfolders: !subfolders.isEmpty,
                subfolders: subfolders
            )
        } catch {
            return FolderNode(url: url, level: level, hasSubfolders: false, subfolders: [])
        }
    }

    private func toggleFolder(_ url: URL) {
        if expandedFolders.contains(url) {
            expandedFolders.remove(url)
        } else {
            expandedFolders.insert(url)
        }
    }

    //Folder Tree Row
    private func folderTreeRow(_ node: FolderNode) -> some View {
        let isSelected = selectedFolder == node.url
        let isExpanded = expandedFolders.contains(node.url)

        return VStack(alignment: .leading, spacing: 0) {
            // Main folder button
            Button {
                selectedFolder = node.url
            } label: {
                HStack {
                    // Indent for level with max constraint to prevent overflow
                    if node.level > 0 {
                        let maxIndent = min(CGFloat(node.level) * 20, UIScreen.main.bounds.width * 0.3)
                        Spacer()
                            .frame(width: maxIndent)
                    }

                    // Dropdown arrow for folders with subfolders
                    if node.hasSubfolders {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleFolder(node.url)
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.blue.opacity(0.7))
                                .frame(width: 12, height: 12)
                                .animation(.easeInOut(duration: 0.2), value: isExpanded)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 16, height: 16)
                    } else {
                        // Empty space to align with folders that have arrows
                        Spacer()
                            .frame(width: 16, height: 16)
                    }

                    // Folder icon
                    Image(systemName: "folder.fill")
                        .foregroundColor(Color.blue.opacity(0.7))

                    // Folder name
                    Text(node.url.lastPathComponent)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded subfolders with smooth animation
            if isExpanded && node.hasSubfolders {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(node.subfolders, id: \.self) { subfolderURL in
                        if let childNode = createChildNode(for: subfolderURL, level: node.level + 1) {
                            AnyView(folderTreeRow(childNode))
                        }
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
    }
}

//FolderPickerView
public class FolderPickerViewController: UIViewController {

    public weak var delegate: FolderPickerDelegate?
    private let configuration: FolderPickerConfiguration
    private var hostingController: UIHostingController<FolderPickerView>?

    //Init
    public init(configuration: FolderPickerConfiguration) {
        self.configuration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let folderPicker = FolderPickerView(configuration: configuration, delegate: self)
        hostingController = UIHostingController(rootView: folderPicker)

        guard let hostingController = hostingController else { return }

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        //Position at bottom of screen
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.heightAnchor.constraint(equalToConstant: 500)
        ])

        //Add tap gesture to dismiss when tapping background
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    @objc private func backgroundTapped() {
        delegate?.folderPickerDidCancel(FolderPickerView(configuration: configuration))
    }
}

//FolderPickerDelegate Implementation
extension FolderPickerViewController: FolderPickerDelegate {
    public func folderPicker(_ picker: FolderPickerView, didSelectFolder url: URL) {
        delegate?.folderPicker(picker, didSelectFolder: url)
    }

    public func folderPickerDidCancel(_ picker: FolderPickerView) {
        delegate?.folderPickerDidCancel(picker)
    }
}

//UIGestureRecognizerDelegate
extension FolderPickerViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle taps on the background (not on the picker itself)
        guard let hostingView = hostingController?.view else { return true }
        let point = touch.location(in: view)
        return !hostingView.frame.contains(point)
    }
}
