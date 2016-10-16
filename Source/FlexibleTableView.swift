//
//  FlexibleTableView.swift
//  FlexibleTableView
//
//  Created by 吴浩文 on 15/7/29.
//  Copyright (c) 2015年 吴浩文. All rights reserved.
//

import UIKit

@objc public protocol FlexibleTableViewDelegate: NSObjectProtocol {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    func tableView(_ tableView: UITableView, numberOfSubRowsAtIndexPath indexPath: IndexPath) -> Int
    func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: IndexPath) -> UITableViewCell
    func tableView(_ tableView: UITableView, cellForSubRowAtIndexPath indexPath: FlexibleIndexPath) -> UITableViewCell
    @objc optional func numberOfSectionsInTableView(_ tableView: UITableView) -> Int
    @objc optional func tableView(_ tableView: UITableView, heightForRowAtIndexPath indexPath: IndexPath) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, heightForSubRowAtIndexPath indexPath: IndexPath) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath)
    @objc optional func tableView(_ tableView: FlexibleTableView, didSelectSubRowAtIndexPath indexPath: FlexibleIndexPath)
    @objc optional func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    @objc optional func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    @objc optional func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    @objc optional func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    @objc optional func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    @objc optional func tableView(_ tableView: UITableView, shouldExpandSubRowsOfCellAtIndexPath indexPath: IndexPath) -> Bool
}

open class FlexibleIndexPath: NSObject{
    open var subRow: Int, row: Int, section: Int, ns: IndexPath
    init(forSubRow subrow:Int,inRow row:Int,inSection section:Int){
        self.subRow = subrow
        self.row=row
        self.section=section
        self.ns=IndexPath(row: row, section: section)
    }
}

open class FlexibleTableView : UITableView, UITableViewDelegate, UITableViewDataSource {
    fileprivate unowned let flexibleTableViewDelegate: FlexibleTableViewDelegate
    open var shouldExpandOnlyOneCell = false
    
    let kIsExpandedKey = "isExpanded"
    let kSubrowsKey = "subrowsCount"
    let kDefaultCellHeight = 44.0
    
    open let expandableCells = NSMutableDictionary()
    
    public init(frame: CGRect,delegate: FlexibleTableViewDelegate) {
        flexibleTableViewDelegate = delegate
        super.init(frame: frame, style: .plain)
        self.delegate=self
        self.dataSource=self
        refreshData()
    }
    required public init?(coder aDecoder: NSCoder) {fatalError("init(coder:) has not been implemented")}
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let correspondingIndexPath = correspondingIndexPathForRowAtIndexPath(indexPath)
        if correspondingIndexPath.subRow == 0 {
            let expandableCell = flexibleTableViewDelegate.tableView(self, cellForRowAtIndexPath:correspondingIndexPath.ns) as! FlexibleTableViewCell
            
            if (expandableCell.expandable) {
                expandableCell.expanded = ((expandableCells[correspondingIndexPath.section] as! NSMutableArray)[correspondingIndexPath.row] as AnyObject)[kIsExpandedKey] as! Bool
                if (expandableCell.expanded){
                    expandableCell.accessoryView!.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI));
                }
            }
            return expandableCell;
        } else {
            let cell = flexibleTableViewDelegate.tableView(self, cellForSubRowAtIndexPath:correspondingIndexPath)
            cell.indentationLevel = 2
            return cell;
        }
    }
    
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated:true)
        
        let cell = tableView.cellForRow(at: indexPath)
        
        if let x = cell as? FlexibleTableViewCell {
            
            var _indexPath = indexPath
            let correspondingIndexPath = correspondingIndexPathForRowAtIndexPath(_indexPath)
            
            flexibleTableViewDelegate.tableView?(self, didSelectRowAtIndexPath:correspondingIndexPath.ns)
            
            if !x.expandable { return }
            
            x.expanded = !x.expanded
        
            if (x.expanded && shouldExpandOnlyOneCell) {
                _indexPath = correspondingIndexPath.ns;
                collapseCurrentlyExpandedIndexPaths()
            }
            
            let numberOfSubRows = numberOfSubRowsAtIndexPath(correspondingIndexPath.ns)
            
            var expandedIndexPaths = [IndexPath]()
            let row = (_indexPath as NSIndexPath).row;
            let section = (_indexPath as NSIndexPath).section;
            
            for index in 1...numberOfSubRows {
                let expIndexPath = IndexPath(row:row+index, section:section)
                expandedIndexPaths.append(expIndexPath)
            }
            
            if (x.expanded) {
                setExpanded(true, forCellAtIndexPath:correspondingIndexPath)
                insertRows(at: expandedIndexPaths, with:UITableViewRowAnimation.top)
            } else {
                setExpanded(false, forCellAtIndexPath:correspondingIndexPath)
                deleteRows(at: expandedIndexPaths, with:UITableViewRowAnimation.top)
            }
            
            x.accessoryViewAnimation()
            
        } else {
            let correspondingIndexPath = correspondingIndexPathForRowAtIndexPath(indexPath)
            
            flexibleTableViewDelegate.tableView?(self, didSelectSubRowAtIndexPath:correspondingIndexPath)
        }
    }
    
    open func numberOfExpandedSubrowsInSection(_ section: Int) -> Int {
        var totalExpandedSubrows = 0;
        
        let rows = expandableCells[section] as! [NSDictionary]
        for row in rows {
            if row[kIsExpandedKey] as! Bool {
                totalExpandedSubrows += row[kSubrowsKey] as! Int
            }
        }
        return totalExpandedSubrows;
    }
    
    open func numberOfSubRowsAtIndexPath(_ indexPath: IndexPath) -> Int {
        return flexibleTableViewDelegate.tableView(self, numberOfSubRowsAtIndexPath:indexPath)
    }
    
    func correspondingIndexPathForRowAtIndexPath(_ indexPath: IndexPath) -> FlexibleIndexPath {
        var expandedSubrows = 0;
        
        let rows = self.expandableCells[(indexPath as NSIndexPath).section] as! NSArray
        for (index, value) in rows.enumerated() {
            let isExpanded = (value as AnyObject)[self.kIsExpandedKey] as! Bool
            var numberOfSubrows = 0;
            if (isExpanded){
                numberOfSubrows = (value as AnyObject)[self.kSubrowsKey] as! Int
            }
            
            let subrow = (indexPath as NSIndexPath).row - expandedSubrows - index;
            if (subrow > numberOfSubrows){
                expandedSubrows += numberOfSubrows;
            }
            else{
                return FlexibleIndexPath(forSubRow: subrow, inRow: index, inSection: (indexPath as NSIndexPath).section)
            }
        }
        return FlexibleIndexPath(forSubRow: 0, inRow: 0, inSection: 0)
    }
    
    open func setExpanded(_ isExpanded: Bool, forCellAtIndexPath indexPath: FlexibleIndexPath) {
        let cellInfo = (expandableCells[indexPath.section] as! NSMutableArray)[indexPath.row] as! NSMutableDictionary
        cellInfo.setObject(isExpanded, forKey:kIsExpandedKey as NSCopying)
    }
    
    open func collapseCurrentlyExpandedIndexPaths() {
        var totalExpandedIndexPaths = [IndexPath]()
        let totalExpandableIndexPaths = NSMutableArray()
        
        for x in expandableCells {
            var totalExpandedSubrows = 0;
            
            for (index, value) in (x.value as! NSArray).enumerated() {
                
                let currentRow = index + totalExpandedSubrows;
                
                if ((value as AnyObject)[kIsExpandedKey] as! Bool)
                {
                    let expandedSubrows = (value as AnyObject)[kSubrowsKey] as! Int
                    
                    for index in 1...expandedSubrows {
                        let expandedIndexPath = IndexPath(row:currentRow + index, section:x.key as! Int)
                        totalExpandedIndexPaths.append(expandedIndexPath)
                    }
                    
                    (value as AnyObject).set(false, forKey:kIsExpandedKey)
                    totalExpandedSubrows += expandedSubrows;
                    
                    totalExpandableIndexPaths.add(IndexPath(row:currentRow, section:x.key as! Int))
                }
            }
        }
        
        
        for indexPath in totalExpandableIndexPaths
        {
            let cell = cellForRow(at: indexPath as! IndexPath) as! FlexibleTableViewCell
            cell.expanded = false
            cell.accessoryViewAnimation()
        }
        
        deleteRows(at: totalExpandedIndexPaths, with:UITableViewRowAnimation.top)
    }
    
    open func refreshData(){
        expandableCells.removeAllObjects()
        for section in 0...numberOfSections-1 {
            let numberOfRowsInSection = flexibleTableViewDelegate.tableView(self, numberOfRowsInSection:section)
            let rows = NSMutableArray()
            for row in 0...numberOfRowsInSection-1 {
                let rowIndexPath = IndexPath(row:row, section:section)
                let numberOfSubrows = flexibleTableViewDelegate.tableView(self, numberOfSubRowsAtIndexPath:rowIndexPath)
                var isExpandedInitially = false
                if let isExpandedInitiallyFromDelegate = flexibleTableViewDelegate.tableView?(self, shouldExpandSubRowsOfCellAtIndexPath:rowIndexPath) {
                    isExpandedInitially = isExpandedInitiallyFromDelegate
                }
                let rowInfo = NSMutableDictionary(objects:[isExpandedInitially, numberOfSubrows], forKeys:[kIsExpandedKey as NSCopying, kSubrowsKey as NSCopying])
                rows.add(rowInfo)
            }
            expandableCells.setObject(rows, forKey:section as NSCopying)
        }
        super.reloadData()
    }
    
    
    
    
    open func numberOfSections(in tableView: UITableView) -> Int{
        if let numberOfSectionsInTableViewFromDelegate = flexibleTableViewDelegate.numberOfSectionsInTableView?(self) {
            return numberOfSectionsInTableViewFromDelegate
        }
        return 1;
    }
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int{
        return flexibleTableViewDelegate.tableView(self, numberOfRowsInSection:section) + numberOfExpandedSubrowsInSection(section)
    }
    open func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat{
        let correspondingIndexPath = correspondingIndexPathForRowAtIndexPath(indexPath)
        if correspondingIndexPath.subRow == 0 {
            if let fromDelegate = flexibleTableViewDelegate.tableView?(self, heightForRowAtIndexPath:correspondingIndexPath.ns) {
                return fromDelegate
            }
            return 44.0;
        } else {
            if let fromDelegate = flexibleTableViewDelegate.tableView?(self, heightForSubRowAtIndexPath:correspondingIndexPath.ns) {
                return fromDelegate
            }
            return 44.0;
        }
    }
    open func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if let fromDelegate = flexibleTableViewDelegate.tableView?(self, heightForHeaderInSection: section) {
            return fromDelegate
        }
        return 0.0
    }
    open func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if let fromDelegate = flexibleTableViewDelegate.tableView?(self, heightForFooterInSection: section) {
            return fromDelegate
        }
        return 0.0
    }
    open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return flexibleTableViewDelegate.tableView?(self, titleForHeaderInSection: section)
    }
    open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return flexibleTableViewDelegate.tableView?(self, titleForFooterInSection: section)
    }
    open func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return flexibleTableViewDelegate.tableView?(self, viewForHeaderInSection: section)
    }
    open func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return flexibleTableViewDelegate.tableView?(self, viewForFooterInSection: section)
    }
}
