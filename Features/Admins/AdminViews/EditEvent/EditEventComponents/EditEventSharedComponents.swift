import SwiftUI
import UIKit

struct EditEventCard<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal, 20)
    }
}

struct EditEventRowTitle: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
    }
}

struct EditEventPlainTitle: View {
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
            
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        }
    }
}

struct EditEventBannerImage: View {
    let imageData: Data?
    
    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("DummyImageBanner")
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}
