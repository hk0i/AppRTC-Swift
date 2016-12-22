//
// Created by Gregory McQuillan on 12/19/16.
// Copyright (c) 2016 One Big Function. All rights reserved.
//

import WebRTC
import UIKit

class ARDStatsView: UIView {
  var stats: [RTCLegacyStatsReport] {
    get { return stats }

    set {
      for report in newValue {
        self.statsBuilder.parse(statsReport: report)
      }

      self.statsLabel.text = statsBuilder.statsString
    }
  }

  let statsLabel: UILabel

  let statsBuilder: ARDStatsBuilder

  override init(frame: CGRect) {
    self.statsLabel = UILabel(frame: .zero)
    self.statsLabel.numberOfLines = 0
    // note: font omitted
    self.statsLabel.adjustsFontSizeToFitWidth = true
    self.statsLabel.minimumScaleFactor = 0.6
    self.statsLabel.textColor = UIColor.green
    self.addSubview(self.statsLabel)

    self.backgroundColor = UIColor(white: 0, alpha: 0.6)

    self.statsBuilder = ARDStatsBuilder()
  }

  required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
  }

  // note: setStats converted to property

  override func layoutSubviews() {
    self.statsLabel.frame = self.bounds
  }

  override func sizeThatFits(_ size: CGSize) -> CGSize {
    return self.statsLabel.sizeThatFits(size)
  }
}
