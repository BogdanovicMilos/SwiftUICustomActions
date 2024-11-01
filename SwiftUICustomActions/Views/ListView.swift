//
//  ListView.swift
//  SwiftUICustomActions
//
//  Created by Milos Bogdanovic on 10/31/24.
//

import SwiftUI


struct ListView: View {
    
    // MARK: - Properties
    
    @State private var showingOptions = false

    // MARK: - View
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 5) {
                Text("Accounts")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.custom(style: .bold, ofSize: .title3))
                    .padding(4)
            }
            .padding(.horizontal, 20)
            
            VStack {
                items
            }
        }
    }
    
    @ViewBuilder
    private var items: some View {
        List {
            ForEach(Account.accounts) { item in
                SwipeView {
                    ZStack(alignment: .leading) {
                        itemRow(item)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 6)
                    .padding(EdgeInsets(top: -1, leading: 0, bottom: -1, trailing: 0))
                    .listRowInsets(EdgeInsets())
                    .background(Color(uiColor: Color.accountBackgroundPrimary))
                    .cornerRadius(20)
                } trailingActions: { _ in
                    SwipeAction(systemImage: "trash", backgroundColor: Color.red.opacity(0.7)) {
                        showingOptions = true
                    }
                }
                .swipeActionsStyle(.cascade)
                .swipeActionCornerRadius(20)
                .swipeSpacing(2)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .confirmationDialog(Strings.Dialog.accountDelete, isPresented: $showingOptions, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {}
        }
    }
    
    @ViewBuilder
    private func itemRow(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 4){
            Text("")
                .font(.custom(style: .bold, ofSize: .body))
            
            Text("")
                .font(.custom(ofSize: .body))
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden, edges: .top)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

#Preview {
    ListView()
}
