//
//  ServerStatusView.swift
//  MRFileBrowser
//
//  Created by Mukilarasan Ravi on 26/01/26.
//

import SwiftUI

struct ServerStatusView: View {
    @ObservedObject var serverManager: FileServerManager
    @State private var showQRCode = false
    @State private var showServerDetails = false

    var body: some View {
        VStack(spacing: 16) {
            // Server Status Header
            HStack {
                Image(systemName: serverManager.isServerRunning ? "wifi.circle.fill" : "wifi.slash")
                    .foregroundColor(Color.blue.opacity(0.7))
                    .font(.title)

                Text(serverManager.isServerRunning ? "Server Running" : "Server Stopped")
                    .font(.headline)

                Spacer()

                if serverManager.isServerRunning {
                    Button(action: { showQRCode.toggle() }) {
                        Image(systemName: "qrcode")
                            .foregroundColor(.blue)
                    }
                }
            }

            if serverManager.isServerRunning {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("URL:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(serverManager.serverURL)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.blue)
                            .onTapGesture {
                                UIPasteboard.copyToClipboard(serverManager.serverURL, showToast: true)
                            }

                        Spacer()

                        Button("Copy") {
                            UIPasteboard.copyToClipboard(serverManager.serverURL, showToast: true)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Connected Clients:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("\(serverManager.connectedClients)")
                            .font(.caption)
                            .foregroundColor(.primary)

                        Spacer()
                    }

                    Text("Only devices on the same WiFi network can access this server")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showQRCode) {
            QRCodeView(url: serverManager.serverURL)
        }
    }
}

struct QRCodeView: View {
    let url: String
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Scan to access server")
                    .font(.title)
                    .padding(.top)

                if let qrImage = generateQRCode(from: url) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .cornerRadius(12)
                        .overlay(
                            Text("QR Code\nGeneration Failed")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        )
                }

                Text(url)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onTapGesture {
                        UIPasteboard.copyToClipboard(url, showToast: true)
                    }

                Spacer()
            }
            .navigationBarItems(
                trailing: Button("Done") { presentationMode.wrappedValue.dismiss() }
            )
        }
        .toast()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
                let context = CIContext()
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
        }

        return nil
    }
}
