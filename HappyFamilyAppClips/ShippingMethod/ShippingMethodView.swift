//
//  ShippingMethodView.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct ShippingMethodView: View {
    @State private var selectedMethod: ShippingMethodModel = .direct

    var body: some View {
        VStack {
            header

            ScrollView {
                VStack(alignment: .leading) {
                    titleSection
                    shippingOptions
                }
                .padding(.top, 26)
            }

            submitButton
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }
}

// MARK: - Header

private extension ShippingMethodView {
    var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button {} label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(AppColor.textDarkCyan)
                }
                .buttonStyle(.automatic)
                

                Spacer()

                Text("Step 3 of 3")
                    .font(.caption)
            }
            progressBar
        }
    }

    var progressBar: some View {
        HStack(spacing: 5) {
            ForEach(0 ..< 3) { _ in
                Capsule()
                    .fill(AppColor.primaryCyan)
                    .frame(height: 7)
            }
        }
    }
}

// MARK: - Title

private extension ShippingMethodView {
    var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Mau dikirim pake apa?")
                .font(.title.bold())
                .foregroundStyle(AppColor.textDarkCyan)

            Text("Pilih metode pengiriman, dan lakukan\npengiriman maksimal dalam 3 hari kedepan.")
                .font(.body)
                .foregroundStyle(AppColor.textDarkCyan)
        }
    }
}

// MARK: - Shipping Options

private extension ShippingMethodView {
    var shippingOptions: some View {
        VStack(spacing: 12) {
            ForEach(ShippingMethodModel.allCases) { method in
                ShippingMethodCard(
                    method: method,
                    isSelected: selectedMethod == method
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedMethod = method
                    }
                }
            }
        }
        .padding(.top, 26)
    }
}

// MARK: - Submit Button

private extension ShippingMethodView {
    var submitButton: some View {
        Button {
            print("Shipping method: \(selectedMethod.rawValue)")
        } label: {
            Text("Kirim Pakaian")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    Capsule()
                        .fill(AppColor.primaryCyan)
                )
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ShippingMethodView()
}
