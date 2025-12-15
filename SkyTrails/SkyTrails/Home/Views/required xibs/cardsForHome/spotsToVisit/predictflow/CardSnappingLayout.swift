//
//  CardSnappingLayout.swift
//  SkyTrails
//
//  Created by SDC-USER on 12/15/25.
//

import UIKit

// MARK: - Custom Snapping Layout
class CardSnappingLayout: UICollectionViewFlowLayout {
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint, withScrollingVelocity velocity: CGPoint) -> CGPoint {
        
        guard let collectionView = collectionView else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        
        // 1. Calculate the center of the "proposed" landing spot
        let targetRect = CGRect(x: proposedContentOffset.x, y: 0, width: collectionView.bounds.width, height: collectionView.bounds.height)
        let horizontalCenter = proposedContentOffset.x + (collectionView.bounds.width / 2.0)
        
        // 2. Find the cell closest to that center
        var offsetAdjustment = CGFloat.greatestFiniteMagnitude
        
        // Inspect all visible attributes in the target area
        guard let attributesList = super.layoutAttributesForElements(in: targetRect) else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        
        for layoutAttributes in attributesList {
            let itemHorizontalCenter = layoutAttributes.center.x
            
            // Find distance from the center
            if abs(itemHorizontalCenter - horizontalCenter) < abs(offsetAdjustment) {
                offsetAdjustment = itemHorizontalCenter - horizontalCenter
            }
        }
        
        // 3. Snap to that item's center
        return CGPoint(x: proposedContentOffset.x + offsetAdjustment, y: proposedContentOffset.y)
    }
}
