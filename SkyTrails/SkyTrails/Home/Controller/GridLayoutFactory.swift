//
//  GridLayoutFactory.swift
//  SkyTrails
//
//  Created by SDC-USER on 19/02/26.
//
import UIKit

enum GridLayoutFactory {

    // MARK: - Item Size

    /// Calculates and returns the absolute card size based on the device's
    /// portrait screen width. Call once and cache the result.
    static func makeItemSize(for view: UIView) -> NSCollectionLayoutSize {
        let screenBounds  = view.window?.windowScene?.screen.bounds ?? view.bounds
        let portraitWidth = min(screenBounds.width, screenBounds.height)
        let padding: CGFloat   = 16
        let spacing: CGFloat   = 16
        let maxCardWidth: CGFloat = 300
        let minColumns = 2

        var columnCount = minColumns
        var width = (portraitWidth - spacing * CGFloat(columnCount - 1) - 2 * padding) / CGFloat(columnCount)
        while width > maxCardWidth {
            columnCount += 1
            width = (portraitWidth - spacing * CGFloat(columnCount - 1) - 2 * padding) / CGFloat(columnCount)
        }

        let height = width * (91.0 / 88.0)
        return NSCollectionLayoutSize(widthDimension: .absolute(width),
                                      heightDimension: .absolute(height))
    }

    // MARK: - Section

    /// Builds a compositional-layout section that fills `containerWidth`
    /// with as many columns as fit the pre-calculated `cachedSize`.
    static func makeSection(cachedSize: NSCollectionLayoutSize,
                             containerWidth: CGFloat,
                             includeHeader: Bool) -> NSCollectionLayoutSection {
        let itemWidth      = cachedSize.widthDimension.dimension
        let interSpacing: CGFloat = 8
        let estimatedCols  = max(1, Int((containerWidth + interSpacing) / (itemWidth + interSpacing)))

        let groupItemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(estimatedCols)),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: groupItemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(cachedSize.heightDimension.dimension)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 24, trailing: 8)

        if includeHeader {
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
        }

        return section
    }
}
