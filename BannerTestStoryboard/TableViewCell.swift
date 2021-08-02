//
//  TableViewCell.swift
//  BannerTestStoryboard
//
//  Created by Ivan Ganzha on 09.02.2021.
//  Copyright © 2021 Ivan Ganzha. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {
    
    
    @IBOutlet weak var itemLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
