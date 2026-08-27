//
//  ShippingMethodView.swift
//  HappyFamilyAppClips
//
//  Created by binc876 on 27/08/26.
//

import SwiftUI

struct ShippingMethodView: View {
    @State private var viewModel = ShippingMethodViewModel()
    
    var body: some View {
        VStack() {
            // header - progress
            header
            
            // metode pengiriman
            ScrollView {
                VStack(alignment: .leading) {
                    // title
                    titleSection
                    
                    // shipping options
                    shippingOptions
                }
                .padding(.top, 26)
            }
            
//            Spacer()
            
            // submit button
            submitButton
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
    }
}

// header
private extension ShippingMethodView {
    var header: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    // back button
                    
                } label: {
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
            ForEach(0..<3) { _ in
                Capsule()
                    .fill(AppColor.primaryCyan)
                    .frame(height: 7)
            }
        }
    }
}

// title
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

// shipping options
private extension ShippingMethodView {

    var shippingOptions: some View {
        VStack(spacing: 12) {

            ForEach(ShippingMethodModel.allCases) { method in

                ShippingMethodCard(
                    method: method,
                    isSelected: viewModel.selectedMethod == method
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.select(method)
                    }
                }
            }
        }
        .padding(.top, 26)
    }
}

// submit button
private extension ShippingMethodView {

    var submitButton: some View {
        Button {
            viewModel.submit()
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
        .padding(.bottom, 0)
    }
}

#Preview {
    ShippingMethodView()
}
