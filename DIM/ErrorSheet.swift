//
//  ErrorSheet.swift
//  DIM 3.0
//
//  Created by G.J. Parker on 19/1/24.
//  Copyright © 2019 G.J. Parker. All rights reserved.
//

import Cocoa

class ErrorSheet: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
    @IBAction func quitButton(_ sender: NSButton) {
        exit(0)
    }
}
