import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Kenapa kami membutuhkan datamu?")
                            .font(.title)
                            .bold()

                        Text("Informasi pribadimu membantu kami memastikan proses donasi berjalan dengan lancar dari awal hingga selesai.\n\nKami menggunakan informasi yang kamu berikan untuk keperluan sebagai berikut :\n1. Untuk kepentingan pencatatan dan mengenali donasimu.\n2. Kamu dapat menerima informasi mengenai status dan perjalanan pakaian yang telah kamu donasikan.\n3. Jika ada kendala atau informasi yang perlu dikonfirmasi terkait donasimu, kami dapat menghubungimu.")
                            .font(.footnote)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Privasimu Tetap Terjaga")
                            .font(.title3)
                            .bold()

                        Text("Kami hanya menggunakan informasi pribadimu untuk keperluan yang berkaitan dengan proses donasi dan layanan yang kamu gunakan.\n\nKami berupaya menjaga data pribadimu tetap aman, membatasi akses hanya kepada pihak yang membutuhkan, dan tidak menggunakan informasi tersebut di luar tujuan yang telah dijelaskan tanpa persetujuanmu.\n\nInformasi pribadimu juga tidak akan dibagikan kepada pihak lain kecuali diperlukan untuk menjalankan layanan, diwajibkan oleh hukum, atau telah mendapatkan persetujuan darimu.")
                            .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Tutup kebijakan privasi")
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
