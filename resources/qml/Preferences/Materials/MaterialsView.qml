// Copyright (c) 2022 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.7
import QtQuick.Controls 2.15
import QtQuick.Dialogs 1.2

import UM 1.5 as UM
import Cura 1.0 as Cura

import ".." // Access to ReadOnlyTextArea.qml

Item
{
    id: base

    property QtObject properties
    property var currentMaterialNode: null

    property bool editingEnabled: false
    property string currency: UM.Preferences.getValue("cura/currency") ? UM.Preferences.getValue("cura/currency") : "€"
    property real firstColumnWidth: (width * 0.50) | 0
    property real secondColumnWidth: (width * 0.40) | 0
    property string containerId: ""
    property var materialPreferenceValues: UM.Preferences.getValue("cura/material_settings") ? JSON.parse(UM.Preferences.getValue("cura/material_settings")) : {}
    property var materialManagementModel: CuraApplication.getMaterialManagementModel()

    property double spoolLength: calculateSpoolLength()
    property real costPerMeter: calculateCostPerMeter()

    signal resetSelectedMaterial()

    property bool reevaluateLinkedMaterials: false
    property string linkedMaterialNames:
    {
        if (reevaluateLinkedMaterials)
        {
            reevaluateLinkedMaterials = false;
        }
        if (!base.containerId || !base.editingEnabled || !base.currentMaterialNode)
        {
            return "";
        }
        var linkedMaterials = Cura.ContainerManager.getLinkedMaterials(base.currentMaterialNode, true);
        if (linkedMaterials.length == 0)
        {
            return "";
        }
        return linkedMaterials.join(", ");
    }

    function getApproximateDiameter(diameter)
    {
        return Math.round(diameter);
    }

    // This trick makes sure to make all fields lose focus so their onEditingFinished will be triggered
    // and modified values will be saved. This can happen when a user changes a value and then closes the
    // dialog directly.
    //
    // Please note that somehow this callback is ONLY triggered when visible is false.
    onVisibleChanged:
    {
        if (!visible)
        {
            base.focus = false;
        }
    }

    UM.TabRow
    {
        id: pageSelectorTabRow
        UM.TabRowButton
        {
            text: catalog.i18nc("@title", "Information")
            property string activeView: "information" //To determine which page gets displayed.
        }
        UM.TabRowButton
        {
            text: catalog.i18nc("@label", "Print settings")
            property string activeView: "settings"
        }
    }

    ScrollView
    {
        id: informationPage
        anchors
        {
            top: pageSelectorTabRow.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        ScrollBar.vertical: UM.ScrollBar
        {
            parent: informationPage
            anchors
            {
                top: parent.top
                right: parent.right
                bottom: parent.bottom
            }
        }
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        clip: true
        visible: pageSelectorTabRow.currentItem.activeView === "information"

        property real columnWidth: (width * 0.5 - UM.Theme.getSize("default_margin").width) | 0

        Flow
        {
            id: containerGrid

            x: UM.Theme.getSize("default_margin").width
            y: UM.Theme.getSize("default_lining").height

            width: base.width
            property real rowHeight: brandTextField.height + UM.Theme.getSize("default_lining").height

            Cura.MessageDialog
            {
                id: confirmDiameterChangeDialog

                title: catalog.i18nc("@title:window", "Confirm Diameter Change")
                text: catalog.i18nc("@label (%1 is a number)", "The new filament diameter is set to %1 mm, which is not compatible with the current extruder. Do you wish to continue?".arg(new_diameter_value))
                standardButtons: Dialog.Yes | Dialog.No

                property var new_diameter_value: null
                property var old_diameter_value: null
                property var old_approximate_diameter_value: null

                onAccepted:
                {
                    base.setMetaDataEntry("approximate_diameter", old_approximate_diameter_value, getApproximateDiameter(new_diameter_value).toString());
                    base.setMetaDataEntry("properties/diameter", properties.diameter, new_diameter_value);
                    // CURA-6868 Make sure to update the extruder to user a diameter-compatible material.
                    Cura.MachineManager.updateMaterialWithVariant()
                    base.resetSelectedMaterial()
                }

                onRejected:
                {
                    base.properties.diameter = old_diameter_value;
                    diameterSpinBox.value = Qt.binding(function() { return base.properties.diameter })
                }
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Display Name") }
            Cura.TextField
            {
                id: displayNameTextField;
                width: informationPage.columnWidth;
                text: properties.name;
                enabled: base.editingEnabled;
                onEditingFinished: base.updateMaterialDisplayName(properties.name, text)
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Brand") }
            Cura.TextField
            {
                id: brandTextField
                width: informationPage.columnWidth
                text: properties.brand
                enabled: base.editingEnabled
                onEditingFinished: base.updateMaterialBrand(properties.brand, text)
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Material Type") }
            Cura.TextField
            {
                id: materialTypeField
                width: informationPage.columnWidth
                text: properties.material
                enabled: base.editingEnabled
                onEditingFinished: base.updateMaterialType(properties.material, text)
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Color") }
            Row
            {
                width: informationPage.columnWidth
                height:  parent.rowHeight
                spacing: Math.round(UM.Theme.getSize("default_margin").width / 2)

                // color indicator square
                Rectangle
                {
                    id: colorSelector
                    color: properties.color_code

                    width: Math.round(colorLabel.height * 0.75)
                    height: Math.round(colorLabel.height * 0.75)
                    border.width: UM.Theme.getSize("default_lining").height

                    anchors.verticalCenter: parent.verticalCenter

                    // open the color selection dialog on click
                    MouseArea
                    {
                        anchors.fill: parent
                        onClicked: colorDialog.open()
                        enabled: base.editingEnabled
                    }
                }

                // pretty color name text field
                Cura.TextField
                {
                    id: colorLabel;
                    width: parent.width - colorSelector.width - parent.spacing
                    text: properties.color_name;
                    enabled: base.editingEnabled
                    onEditingFinished: base.setMetaDataEntry("color_name", properties.color_name, text)
                }

                // popup dialog to select a new color
                // if successful it sets the properties.color_code value to the new color
                Cura.ColorDialog
                {
                    id: colorDialog
                    title: catalog.i18nc("@title", "Material color picker")
                    color: properties.color_code
                    onAccepted: base.setMetaDataEntry("color_code", properties.color_code, color)
                }
            }

            Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }

            Label { width: parent.width; height: parent.rowHeight; font.bold: true; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Properties") }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Density") }

            Cura.SpinBox
            {
                enabled: base.editingEnabled
                id: densitySpinBox
                width: informationPage.columnWidth
                value: properties.density
                decimals: 2
                suffix: " g/cm³"
                stepSize: 0.01

                onEditingFinished: base.setMetaDataEntry("properties/density", properties.density, value)
                onValueChanged: updateCostPerMeter()
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Diameter") }
            Cura.SpinBox
            {
                enabled: base.editingEnabled
                id: diameterSpinBox
                width: informationPage.columnWidth
                value: properties.diameter
                decimals: 2
                suffix: " mm"
                stepSize: 0.01

                onEditingFinished:
                {
                    // This does not use a SettingPropertyProvider, because we need to make the change to all containers
                    // which derive from the same base_file
                    var old_diameter = Cura.ContainerManager.getContainerMetaDataEntry(base.containerId, "properties/diameter");
                    var old_approximate_diameter = Cura.ContainerManager.getContainerMetaDataEntry(base.containerId, "approximate_diameter");
                    var new_approximate_diameter = getApproximateDiameter(value);
                    if (new_approximate_diameter != Cura.ExtruderManager.getActiveExtruderStack().approximateMaterialDiameter)
                    {
                        confirmDiameterChangeDialog.old_diameter_value = old_diameter;
                        confirmDiameterChangeDialog.new_diameter_value = value;
                        confirmDiameterChangeDialog.old_approximate_diameter_value = old_approximate_diameter;

                        confirmDiameterChangeDialog.open()
                    }
                    else {
                        base.setMetaDataEntry("approximate_diameter", old_approximate_diameter, getApproximateDiameter(value).toString());
                        base.setMetaDataEntry("properties/diameter", properties.diameter, value);
                    }
                }
                onValueChanged: updateCostPerMeter()
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament Cost") }

            Cura.SpinBox
            {
                id: spoolCostSpinBox
                width: informationPage.columnWidth
                value: base.getMaterialPreferenceValue(properties.guid, "spool_cost")
                to: 100000000
                editable: true
                prefix: base.currency + " "
                decimals: 2

                onValueChanged:
                {
                    base.setMaterialPreferenceValue(properties.guid, "spool_cost", parseFloat(value))
                    updateCostPerMeter()
                }
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament weight") }
            Cura.SpinBox
            {
                id: spoolWeightSpinBox
                width: informationPage.columnWidth
                value: base.getMaterialPreferenceValue(properties.guid, "spool_weight", Cura.ContainerManager.getContainerMetaDataEntry(properties.container_id, "properties/weight"))
                stepSize: 100
                to: 10000
                editable: true
                suffix: " g"

                onValueChanged:
                {
                    base.setMaterialPreferenceValue(properties.guid, "spool_weight", parseFloat(value))
                    updateCostPerMeter()
                }
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Filament length") }
            Label
            {
                width: informationPage.columnWidth
                text: "~ %1 m".arg(Math.round(base.spoolLength))
                verticalAlignment: Qt.AlignVCenter
                height: parent.rowHeight
            }

            Label { width: informationPage.columnWidth; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Cost per Meter") }
            Label
            {
                width: informationPage.columnWidth
                text: "~ %1 %2/m".arg(base.costPerMeter.toFixed(2)).arg(base.currency)
                verticalAlignment: Qt.AlignVCenter
                height: parent.rowHeight
            }

            Item { width: parent.width; height: UM.Theme.getSize("default_margin").height; visible: unlinkMaterialButton.visible }
            Label
            {
                width: 2 * informationPage.columnWidth
                verticalAlignment: Qt.AlignVCenter
                text: catalog.i18nc("@label", "This material is linked to %1 and shares some of its properties.").arg(base.linkedMaterialNames)
                wrapMode: Text.WordWrap
                visible: unlinkMaterialButton.visible
            }
            Button
            {
                id: unlinkMaterialButton
                text: catalog.i18nc("@label", "Unlink Material")
                visible: base.linkedMaterialNames != ""
                onClicked:
                {
                    Cura.ContainerManager.unlinkMaterial(base.currentMaterialNode)
                    base.reevaluateLinkedMaterials = true
                }
            }

            Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }

            Label { width: parent.width; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Description") }

            ReadOnlyTextArea
            {
                text: properties.description;
                width: informationPage.columnWidth * 2
                height: 0.75 * informationPage.columnWidth
                wrapMode: Text.WordWrap

                readOnly: !base.editingEnabled

                onEditingFinished: base.setMetaDataEntry("description", properties.description, text)
            }

            Label { width: parent.width; height: parent.rowHeight; verticalAlignment: Qt.AlignVCenter; text: catalog.i18nc("@label", "Adhesion Information") }

            ReadOnlyTextArea
            {
                text: properties.adhesion_info
                width: 2 * informationPage.columnWidth
                wrapMode: Text.WordWrap
                height: 0.75 * informationPage.columnWidth
                readOnly: !base.editingEnabled

                onEditingFinished: base.setMetaDataEntry("adhesion_info", properties.adhesion_info, text)
            }

            Item { width: parent.width; height: UM.Theme.getSize("default_margin").height }
        }
    }

    ListView
    {
        anchors
        {
            top: pageSelectorTabRow.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        model: UM.SettingDefinitionsModel
        {
            containerId: Cura.MachineManager.activeMachine != null ? Cura.MachineManager.activeMachine.definition.id: ""
            visibilityHandler: Cura.MaterialSettingsVisibilityHandler { }
            expanded: ["*"]
        }
        ScrollBar.vertical: UM.ScrollBar {}
        clip: true
        visible: pageSelectorTabRow.currentItem.activeView === "settings"

        delegate: UM.TooltipArea
        {
            width: childrenRect.width
            height: childrenRect.height
            text: model.description
            Label
            {
                id: label
                width: base.firstColumnWidth;
                height: spinBox.height + UM.Theme.getSize("default_lining").height
                text: model.label
                elide: Text.ElideRight
                verticalAlignment: Qt.AlignVCenter
            }
            Cura.SpinBox
            {
                id: spinBox
                anchors.left: label.right
                value:
                {
                    // In case the setting is not in the material...
                    if (!isNaN(parseFloat(materialPropertyProvider.properties.value)))
                    {
                        return parseFloat(materialPropertyProvider.properties.value);
                    }
                    // ... we search in the variant, and if it is not there...
                    if (!isNaN(parseFloat(variantPropertyProvider.properties.value)))
                    {
                        return parseFloat(variantPropertyProvider.properties.value);
                    }
                    // ... then look in the definition container.
                    if (!isNaN(parseFloat(machinePropertyProvider.properties.value)))
                    {
                        return parseFloat(machinePropertyProvider.properties.value);
                    }
                    return 0;
                }
                width: base.secondColumnWidth
                suffix: " " + model.unit
                to: 99999
                decimals: model.unit == "mm" ? 2 : 0

                onEditingFinished: materialPropertyProvider.setPropertyValue("value", value)
            }

            UM.ContainerPropertyProvider
            {
                id: materialPropertyProvider
                containerId: base.containerId
                watchedProperties: [ "value" ]
                key: model.key
            }
            UM.ContainerPropertyProvider
            {
                id: variantPropertyProvider
                containerId: Cura.MachineManager.activeStack.variant.id
                watchedProperties: [ "value" ]
                key: model.key
            }
            UM.ContainerPropertyProvider
            {
                id: machinePropertyProvider
                containerId: Cura.MachineManager.activeMachine != null ? Cura.MachineManager.activeMachine.definition.id: ""
                watchedProperties: [ "value" ]
                key: model.key
            }
        }
    }

    function updateCostPerMeter()
    {
        base.spoolLength = calculateSpoolLength(diameterSpinBox.value, densitySpinBox.value, spoolWeightSpinBox.value);
        base.costPerMeter = calculateCostPerMeter(spoolCostSpinBox.value);
    }

    function calculateSpoolLength(diameter, density, spoolWeight)
    {
        if(!diameter)
        {
            diameter = properties.diameter;
        }
        if(!density)
        {
            density = properties.density;
        }
        if(!spoolWeight)
        {
            spoolWeight = base.getMaterialPreferenceValue(properties.guid, "spool_weight", Cura.ContainerManager.getContainerMetaDataEntry(properties.container_id, "properties/weight"));
        }

        if (diameter == 0 || density == 0 || spoolWeight == 0)
        {
            return 0;
        }
        var area = Math.PI * Math.pow(diameter / 2, 2); // in mm2
        var volume = (spoolWeight / density); // in cm3
        return volume / area; // in m
    }

    function calculateCostPerMeter(spoolCost)
    {
        if(!spoolCost)
        {
            spoolCost = base.getMaterialPreferenceValue(properties.guid, "spool_cost");
        }

        if (spoolLength == 0)
        {
            return 0;
        }
        return spoolCost / spoolLength;
    }

    // Tiny convenience function to check if a value really changed before trying to set it.
    function setMetaDataEntry(entry_name, old_value, new_value)
    {
        if (old_value != new_value)
        {
            Cura.ContainerManager.setContainerMetaDataEntry(base.currentMaterialNode, entry_name, new_value)
            // make sure the UI properties are updated as well since we don't re-fetch the entire model here
            // When the entry_name is something like properties/diameter, we take the last part of the entry_name
            var list = entry_name.split("/")
            var key = list[list.length - 1]
            properties[key] = new_value
        }
    }

    function setMaterialPreferenceValue(material_guid, entry_name, new_value)
    {
        if(!(material_guid in materialPreferenceValues))
        {
            materialPreferenceValues[material_guid] = {};
        }
        if(entry_name in materialPreferenceValues[material_guid] && materialPreferenceValues[material_guid][entry_name] == new_value)
        {
            // value has not changed
            return;
        }
        if (entry_name in materialPreferenceValues[material_guid] && new_value.toString() == 0)
        {
            // no need to store a 0, that's the default, so remove it
            materialPreferenceValues[material_guid].delete(entry_name);
            if (!(materialPreferenceValues[material_guid]))
            {
                // remove empty map
                materialPreferenceValues.delete(material_guid);
            }
        }
        if (new_value.toString() != 0)
        {
            // store new value
            materialPreferenceValues[material_guid][entry_name] = new_value;
        }

        // store preference
        UM.Preferences.setValue("cura/material_settings", JSON.stringify(materialPreferenceValues));
    }

    function getMaterialPreferenceValue(material_guid, entry_name, default_value)
    {
        if(material_guid in materialPreferenceValues && entry_name in materialPreferenceValues[material_guid])
        {
            return materialPreferenceValues[material_guid][entry_name];
        }
        default_value = default_value | 0;
        return default_value;
    }

    // update the display name of the material
    function updateMaterialDisplayName(old_name, new_name)
    {
        // don't change when new name is the same
        if (old_name == new_name)
        {
            return
        }

        // update the values
        base.materialManagementModel.setMaterialName(base.currentMaterialNode, new_name)
        properties.name = new_name
    }

    // update the type of the material
    function updateMaterialType(old_type, new_type)
    {
        base.setMetaDataEntry("material", old_type, new_type)
        properties.material = new_type
    }

    // update the brand of the material
    function updateMaterialBrand(old_brand, new_brand)
    {
        base.setMetaDataEntry("brand", old_brand, new_brand)
        properties.brand = new_brand
    }
}
