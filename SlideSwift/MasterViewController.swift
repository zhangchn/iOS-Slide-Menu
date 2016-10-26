//
//  MasterViewController.swift
//  SlideSwift
//
//  Created by ZhangChen on 10/3/15.
//  Copyright © 2015 Aryan Ghassemi. All rights reserved.
//

import UIKit

class MasterViewController: UITabBarController, SSlideNavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.leftBarButtonItem = self.editButtonItem

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//    func insertNewObject(sender: AnyObject) {
//        objects.insert(NSDate(), atIndex: 0)
//        let indexPath = NSIndexPath(forRow: 0, inSection: 0)
//        self.tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
//    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    }

    // MARK: - Table View

    
    func slideNavigationControllerShouldDisplayRightMenu() -> Bool {
        return true
    }
    func slideNavigationControllerShouldDisplayLeftMenu() -> Bool {
        return true        
    }
    
}

