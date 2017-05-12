//
// Created by Rick Mark on 5/1/17.
// Copyright (c) 2017 Hot Mess and Co. All rights reserved.
//

import Foundation

class DataResult {
    let success: Bool
    let data: [ String : Any ]!
    let error: Error?
    let request: DataRequest

    init(_ request: DataRequest, error: Error?) {
        self.request = request
        self.data = nil
        self.error = error
        self.success = false
    }

    init(_ request: DataRequest, data: [ String : Any ]) {
        self.success = true
        self.data = data
        self.request = request
        self.error = nil
    }
}
