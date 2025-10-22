//Copyright (c) 2022 Ultimaker B.V.
//Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.7
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3
import QtQuick.Dialogs 1.2

import UM 1.5 as UM
import Cura 1.6 as Cura


UM.ManagementPage
{
    id: base

    property var extrudersModel: CuraApplication.getExtrudersModel()
    property var qualityManagementModel: CuraApplication.getQualityManagementModel()

    scrollviewCaption: catalog.i18nc("@label", "Profiles compatible with active printer:") + "<b>" + Cura.MachineManager.activeMachine.name + "</b>"

    onHamburgeButtonClicked: menu.popup(content_item, content_item.width - menu.width, hamburger_button.height)


    property var hasCurrentItem: base.currentItem != null
    sectionRole: "section_name"

    property var currentItem:
    {
        var current_index = objectList.currentIndex;
        return (current_index == -1) ? null : base.qualityManagementModel.getItem(current_index);
    }

    property var currentItemName: hasCurrentItem ? base.currentItem.name : ""
    property var currentItemDisplayName: hasCurrentItem ? base.qualityManagementModel.getQualityItemDisplayName(base.currentItem) : ""

    property var isCurrentItemActivated:
    {
        if (!base.currentItem)
        {
            return false;
        }
        if (base.currentItem.is_read_only)
        {
            return (base.currentItem.name == Cura.MachineManager.activeQualityOrQualityChangesName) && (base.currentItem.intent_category == Cura.MachineManager.activeIntentCategory);
        }
        else
        {
            return base.currentItem.name == Cura.MachineManager.activeQualityOrQualityChangesName;
        }
    }

    property var canCreateProfile:
    {
        return isCurrentItemActivated && Cura.MachineManager.hasUserSettings;
    }

    model: qualityManagementModel
    buttons: [
        Cura.SecondaryButton
        {
            text: catalog.i18nc("@action:button", "Import")
            onClicked:importDialog.open()
        },
        Cura.SecondaryButton
        {
            id: createMenuButton
            text: catalog.i18nc("@action:button", "Create new")

            enabled: !Cura.MachineManager.stacksHaveErrors
            visible: base.canCreateProfile

            onClicked:
            {
                createQualityDialog.object = Cura.ContainerManager.makeUniqueName(base.currentItem.name)
                createQualityDialog.open()
                createQualityDialog.selectText()
            }
        }
    ]

    // Click create profile from ... in Profile context menu
    signal createProfile()
    onCreateProfile:
    {
        createQualityDialog.object = Cura.ContainerManager.makeUniqueName(Cura.MachineManager.activeQualityOrQualityChangesName);
        createQualityDialog.open();
        createQualityDialog.selectText();
    }

    property string newQualityNameToSelect: ""
    property bool toActivateNewQuality: false

    Item
    {
        id: content_item
        anchors.fill: parent
        // This connection makes sure that we will switch to the correct quality after the model gets updated
        Connections
        {
            target: base.qualityManagementModel
            function onItemsChanged()
            {
                var toSelectItemName = base.currentItem == null ? "" : base.currentItem.name;
                if (newQualityNameToSelect != "")
                {
                    toSelectItemName = newQualityNameToSelect;
                }

                var newIdx = -1;  // Default to nothing if nothing can be found
                if (toSelectItemName != "")
                {
                    // Select the required quality name if given
                    for (var idx = 0; idx < base.qualityManagementModel.count; ++idx)
                    {
                        var item = base.qualityManagementModel.getItem(idx);
                        if (item && item.name == toSelectItemName)
                        {
                            // Switch to the newly created profile if needed
                            newIdx = idx;
                            if (base.toActivateNewQuality)
                            {
                                // Activate this custom quality if required
                                if(item.quality_changes_group)
                                {
                                    Cura.MachineManager.setQualityChangesGroup(item.quality_changes_group);
                                }
                            }
                            break;
                        }
                    }
                }
                objectList.currentIndex = newIdx;

                // Reset states
                base.newQualityNameToSelect = "";
                base.toActivateNewQuality = false;
            }
        }
        Cura.MessageDialog
        {
            id: messageDialog
            standardButtons: Dialog.Ok
        }

        // Dialog to request a name when creating a new profile
        Cura.RenameDialog
        {
            id: createQualityDialog
            title: catalog.i18nc("@title:window", "Create Profile")
            object: "<new name>"
            explanation: catalog.i18nc("@info", "Please provide a name for this profile.")
            onAccepted:
            {
                base.newQualityNameToSelect = newName;  // We want to switch to the new profile once it's created
                base.toActivateNewQuality = true;
                base.qualityManagementModel.createQualityChanges(newName);
            }
        }

        Cura.Menu
        {
            id: menu
            Cura.MenuItem
            {
                text: catalog.i18nc("@action:button", "Activate")

                enabled: !isCurrentItemActivated && base.currentItem
                onTriggered:
                {
                    if(base.currentItem.is_read_only)
                    {
                        Cura.IntentManager.selectIntent(base.currentItem.intent_category, base.currentItem.quality_type)
                    }
                    else
                    {
                        Cura.MachineManager.setQualityChangesGroup(base.currentItem.quality_changes_group)
                    }
                }
            }
            Cura.MenuItem
            {
                text: catalog.i18nc("@action:button", "Remove")
                enabled: base.hasCurrentItem && !base.currentItem.is_read_only && !base.isCurrentItemActivated
                onTriggered:
                {
                    forceActiveFocus()
                    confirmRemoveQualityDialog.open()
                }
            }
            Cura.MenuItem
            {
                text: catalog.i18nc("@action:button", "Rename")
                enabled: base.hasCurrentItem && !base.currentItem.is_read_only
                onTriggered:
                {
                    renameQualityDialog.object = base.currentItem.name
                    renameQualityDialog.open()
                    renameQualityDialog.selectText()
                }
            }
            Cura.MenuItem
            {
                text: catalog.i18nc("@action:button", "Export")
                enabled: base.hasCurrentItem && !base.currentItem.is_read_only
                onTriggered: exportDialog.open()
            }
        }

        // Dialog for exporting a quality profile
        FileDialog
        {
            id: exportDialog
            title: catalog.i18nc("@title:window", "Export Profile")
            selectExisting: false
            nameFilters: base.qualityManagementModel.getFileNameFilters("profile_writer")
            folder: CuraApplication.getDefaultPath("dialog_profile_path")
            onAccepted:
            {
                var result = Cura.ContainerManager.exportQualityChangesGroup(base.currentItem.quality_changes_group,
                                                                             fileUrl, selectedNameFilter);

                if (result && result.status == "error")
                {
                    messageDialog.title = catalog.i18nc("@title:window", "Export Profile")
                    messageDialog.text = result.message;
                    messageDialog.open();
                }

                // else pop-up Message thing from python code
                CuraApplication.setDefaultPath("dialog_profile_path", folder);
            }
        }

        // Dialog to request a name when duplicating a new profile
        Cura.RenameDialog
        {
            id: duplicateQualityDialog
            title: catalog.i18nc("@title:window", "Duplicate Profile")
            object: "<new name>"
            onAccepted:
            {
                base.qualityManagementModel.duplicateQualityChanges(newName, base.currentItem);
            }
        }

        // Confirmation dialog for removing a profile
        Cura.MessageDialog
        {
            id: confirmRemoveQualityDialog

            title: catalog.i18nc("@title:window", "Confirm Remove")
            text: catalog.i18nc("@label (%1 is object name)", "Are you sure you wish to remove %1? This cannot be undone!").arg(base.currentItemName)
            standardButtons: StandardButton.Yes | StandardButton.No
            modal: true

            onAccepted:
            {
                base.qualityManagementModel.removeQualityChangesGroup(base.currentItem.quality_changes_group);
                // reset current item to the first if available
                qualityListView.currentIndex = -1;  // Reset selection.
            }
        }

        // Dialog to rename a quality profile
        Cura.RenameDialog
        {
            id: renameQualityDialog
            title: catalog.i18nc("@title:window", "Rename Profile")
            object: "<new name>"
            onAccepted:
            {
                var actualNewName = base.qualityManagementModel.renameQualityChangesGroup(base.currentItem.quality_changes_group, newName);
                base.newQualityNameToSelect = actualNewName;  // Select the new name after the model gets updated
            }
        }

        // Dialog for importing a quality profile
        FileDialog
        {
            id: importDialog
            title: catalog.i18nc("@title:window", "Import Profile")
            selectExisting: true
            nameFilters: base.qualityManagementModel.getFileNameFilters("profile_reader")
            folder: CuraApplication.getDefaultPath("dialog_profile_path")
            onAccepted:
            {
                var result = Cura.ContainerManager.importProfile(fileUrl);
                messageDialog.title = catalog.i18nc("@title:window", "Import Profile")
                messageDialog.text = result.message;
                messageDialog.open();
                CuraApplication.setDefaultPath("dialog_profile_path", folder);
            }
        }

        Column
        {
            id: detailsPanelHeaderColumn
            anchors
            {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            spacing: UM.Theme.getSize("default_margin").height
            visible: base.currentItem != null
            UM.Label
            {
                anchors.left: parent.left
                anchors.right: parent.right
                text: base.currentItemDisplayName
                font: UM.Theme.getFont("large_bold")
                elide: Text.ElideRight
            }

            Flow
            {
                id: currentSettingsActions
                width: parent.width

                visible: base.hasCurrentItem && base.currentItem.name == Cura.MachineManager.activeQualityOrQualityChangesName && base.currentItem.intent_category == Cura.MachineManager.activeIntentCategory

                Cura.SecondaryButton
                {
                    text: catalog.i18nc("@action:button", "Update profile with current settings/overrides")
                    enabled: Cura.MachineManager.hasUserSettings && objectList.currentIndex && !objectList.currentIndex.is_read_only
                    onClicked: Cura.ContainerManager.updateQualityChanges()
                }

                Cura.SecondaryButton
                {
                    text: catalog.i18nc("@action:button", "Discard current changes");
                    enabled: Cura.MachineManager.hasUserSettings
                    onClicked: Cura.ContainerManager.clearUserContainers();
                }
            }

            UM.Label
            {
                id: defaultsMessage
                visible: false
                text: catalog.i18nc("@action:label", "This profile uses the defaults specified by the printer, so it has no settings/overrides in the list below.")
                width: parent.width
            }
            UM.Label
            {
                id: noCurrentSettingsMessage
                visible: base.isCurrentItemActivated && !Cura.MachineManager.hasUserSettings
                text: catalog.i18nc("@action:label", "Your current settings match the selected profile.")
                width: parent.width
            }

            UM.TabRow
            {
                id: profileExtruderTabs
                UM.TabRowButton //One extra tab for the global settings.
                {
                    text: catalog.i18nc("@title:tab", "Global Settings")
                }

                Repeater
                {
                    model: base.extrudersModel

                    UM.TabRowButton
                    {
                        text: model.name
                    }
                }
            }
        }

        Rectangle
        {
            color: UM.Theme.getColor("main_background")
            anchors
            {
                top: detailsPanelHeaderColumn.bottom
                topMargin: -UM.Theme.getSize("default_lining").width
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            border.width: UM.Theme.getSize("default_lining").width
            border.color: UM.Theme.getColor("thick_lining")
            visible: base.hasCurrentItem
        }

        Cura.ProfileOverview
        {
            anchors
            {
                top: detailsPanelHeaderColumn.bottom
                margins: UM.Theme.getSize("default_margin").height
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }

            visible: detailsPanelHeaderColumn.visible
            qualityItem: base.currentItem
            extruderPosition: profileExtruderTabs.currentIndex - 1
        }
    }
}
