/*
 *  Copyright 2019 Davide Sandona' <sandona.davide@gmail.com>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>
 */

import QtQuick 2.2
import QtQuick.Controls 1.1 as QtControls
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras

import "js/index.js" as ExternalJS

Item {
	id: root

	readonly property bool isVertical: plasmoid.formFactor === PlasmaCore.Types.Vertical

	readonly property int widgetIconSize: plasmoid.configuration.widgetIconSize
	readonly property int updateIntervalMinutes: plasmoid.configuration.updateInterval
	readonly property bool showFlagInCompact: plasmoid.configuration.showFlagInCompact
	readonly property bool showIPInCompact: plasmoid.configuration.showIPInCompact
	readonly property string globe_icon_path: "../icons/globe.svg"

	property real latitude: 0
	property real longitude: 0
	property var jsonData: {}

	property var request: null
	property bool loadingData: false
	property double loadingDataSinceTime: 0
	property int loadingDataTimeoutMs: 15000

	property bool debug: false

	Plasmoid.switchWidth: units.gridUnit * 10
    Plasmoid.switchHeight: units.gridUnit * 12

	Timer {
		id: timer
		interval: updateIntervalMinutes * 60 * 1000
		running: true
		repeat: true
		triggeredOnStart: true
		onTriggered: {
			debug_print("### [Timer onTriggered]")
			reloadData()
			abortTooLongConnection()
		}
	}

	function successCallback(jsonData) {
		root.loadingData = false
		root.jsonData = jsonData
		var coords = jsonData.loc.split(",")
		root.latitude = parseFloat(coords[0])
		root.longitude = parseFloat(coords[1])
		debug_print("### [successCallback]: " + jsonData)
	}

	function failureCallback(request) {
		root.loadingData = false
		debug_print("### [failureCallback]:")
		console.log('ERROR - status: ' + request.status)
		console.log('ERROR - responseText: ' + request.responseText)
	}

	function debug_print(msg) {
		if (debug)
			console.log(msg)
	}

	function reloadData() {
		if (loadingData) {
			debug_print("### [reloadData]: Still loading data")
			return
		}

		var now = (new Date()).getTime()

		loadingDataSinceTime = now
		loadingData = true
		root.request = ExternalJS.getIPdata(successCallback, failureCallback)
	}

	function abortTooLongConnection() {
		if (loadingData) {
			debug_print("### [abortTooLongConnection]: Still loading data")
			return
		}

		var now = (new Date()).getTime()
		debug_print("### [abortTooLongConnection]: loadingDataSinceTime: " + loadingDataSinceTime + " - loadingDataTimeoutMs: " + loadingDataTimeoutMs + " - now: " + now)
		if (loadingDataSinceTime + loadingDataTimeoutMs < nowTime) {
			debug_print("### [abortTooLongConnection]: Time out reached. Aborting request.")
			request.abort()
			loadingData = false
		}
	}

	function getIconPath(isToolTipArea) {
		if (root.jsonData === undefined) {
			return Qt.resolvedUrl(globe_icon_path)
		}

		var country = root.jsonData.country.toLowerCase()
		if (isToolTipArea) {
			return Qt.resolvedUrl("../icons/1x1/" + country + ".svg")
		}

		if (!showFlagInCompact) {
			return Qt.resolvedUrl(globe_icon_path)
		}

		return Qt.resolvedUrl("../icons/1x1/" + country + ".svg")
	}

	Plasmoid.compactRepresentation: MouseArea {
        id: compactRoot
		hoverEnabled: true
		acceptedButtons: Qt.LeftButton | Qt.MiddleButton

		// Taken from DigitalClock to ensure uniform sizing when next to each other
        readonly property bool tooSmall: plasmoid.formFactor === PlasmaCore.Types.Horizontal && Math.round(2 * (compactRoot.height / 5)) <= theme.smallestFont.pixelSize
		readonly property int fontSize: plasmoid.configuration.fontSize
		readonly property bool showWidgetLabel: plasmoid.configuration.showWidgetLabel

		Layout.minimumWidth: compactRow.implicitWidth
		Layout.maximumWidth: Layout.minimumWidth
		Layout.preferredWidth: Layout.minimumWidth

		onClicked: {
			if (mouse.button == Qt.MiddleButton) {
                root.reloadData()
            } else {
                plasmoid.expanded = !plasmoid.expanded
            }
		}

		GridLayout {
			id: compactRow
			anchors.centerIn: parent
			flow: isVertical ? GridLayout.TopToBottom : GridLayout.LeftToRight

			PlasmaCore.SvgItem {
				id: icon
				Layout.minimumWidth: units.iconSizes.tiny
                Layout.minimumHeight: units.iconSizes.tiny
                Layout.maximumWidth: units.iconSizes.enormous
                Layout.maximumHeight: units.iconSizes.enormous
                Layout.preferredWidth: ExternalJS.getIconSize(widgetIconSize, compactRoot)
                Layout.preferredHeight: Layout.preferredWidth
				svg: PlasmaCore.Svg {
					id: svg
					imagePath: getIconPath(false)
				}
			}

			QtControls.Label {
				text: {
					if (!showFlagInCompact) {
						if (showIPInCompact)
							return "IP " + root.jsonData.ip
						return "IP"
					}

					var country = root.jsonData.country.toUpperCase()
					if (showIPInCompact)
						return country + " " + root.jsonData.ip
					return country
				}
				height: compactRoot.height
				fontSizeMode: isVertical ? Text.HorizontalFit : Text.FixedSize
				font.pixelSize: {
                    if (isVertical)
                        return undefined
                    else
                        return tooSmall ? theme.defaultFont.pixelSize : units.roundToIconSize(units.gridUnit * 2) * fontSize / 100
                }
                minimumPointSize: theme.smallestFont.pointSize
				visible: showWidgetLabel
			}
		}

		PlasmaCore.ToolTipArea {
	        anchors.fill: parent
	        icon: getIconPath(true)
	        mainText: i18n('Public IP Address')
			subText: {
				var details = i18n("Public IP Address: ")
				if (root.jsonData !== undefined) {
					details += "<b>" + root.jsonData.ip + "</b>"
					details += "<br/>"
					details += i18n("Connected to: ")
					details += "<b>" + root.jsonData.country + ", " + root.jsonData.region + ", " + root.jsonData.city + "</b>"
				}
				else {
					details += details += "<b>N/A</b>"
				}
				return details
			}
	    }
	}

	Plasmoid.fullRepresentation: FullRepresentation {}

}
