#!/usr/bin/env python3
"""Writes the shortcut the phone's automation runs to send a message on (see Shared/MessageRelay.swift).

The relay texts the phone `quasi|<number>|<text>`. This shortcut splits that at the bars and
sends the text to the number with Messages, from the owner's own number, without showing
anything. For `quasi|note|<text>` it makes a note of the text in Apple Notes instead. The automation that runs it ("when a message containing `quasi|` arrives, run
immediately") has to be made by hand in the Shortcuts app; automations cannot be imported.

Usage: tools/make_relay_shortcut.py      (writes tools/Quasi Relay.shortcut, signed so it can be imported)
"""
import os, plistlib, subprocess, tempfile, uuid

split, item2, item3, branch = (str(uuid.uuid4()).upper() for _ in range(4))


def ref(u, name):
    return {"OutputUUID": u, "OutputName": name, "Type": "ActionOutput"}


def attachment(u, name):
    return {"Value": ref(u, name), "WFSerializationType": "WFTextTokenAttachment"}


def token_string(u, name):
    return {"Value": {"attachmentsByRange": {"{0, 1}": ref(u, name)}, "string": "￼"}, "WFSerializationType": "WFTextTokenString"}


actions = [
    {"WFWorkflowActionIdentifier": "is.workflow.actions.text.split",
     "WFWorkflowActionParameters": {"UUID": split, "WFTextSeparator": "Custom", "WFTextCustomSeparator": "|",
                                    "text": {"Value": {"Type": "ExtensionInput"}, "WFSerializationType": "WFTextTokenAttachment"}}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getitemfromlist",
     "WFWorkflowActionParameters": {"UUID": item2, "WFItemSpecifier": "Item At Index", "WFItemIndex": 2, "WFInput": attachment(split, "Split Text")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.getitemfromlist",
     "WFWorkflowActionParameters": {"UUID": item3, "WFItemSpecifier": "Item At Index", "WFItemIndex": 3, "WFInput": attachment(split, "Split Text")}},
    # "note" in the second place: keep the text in Apple Notes. Otherwise it is a number: send the text there.
    {"WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
     "WFWorkflowActionParameters": {"GroupingIdentifier": branch, "WFControlFlowMode": 0, "WFCondition": 4,
                                    "WFConditionalActionString": "note", "WFInput": {"Type": "Variable", "Variable": attachment(item2, "Item from List")}}},
    {"WFWorkflowActionIdentifier": "com.apple.mobilenotes.SharingExtension",
     "WFWorkflowActionParameters": {"ShowWhenRun": False, "WFCreateNoteInput": token_string(item3, "Item from List")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
     "WFWorkflowActionParameters": {"GroupingIdentifier": branch, "WFControlFlowMode": 1}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.sendmessage",
     "WFWorkflowActionParameters": {"ShowWhenRun": False,
                                    "WFSendMessageContent": token_string(item3, "Item from List"),
                                    "WFSendMessageActionRecipients": token_string(item2, "Item from List")}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.conditional",
     "WFWorkflowActionParameters": {"GroupingIdentifier": branch, "WFControlFlowMode": 2}},
]
workflow = {
    "WFWorkflowClientVersion": "2607.0.3",
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowIcon": {"WFWorkflowIconStartColor": 4282601983, "WFWorkflowIconGlyphNumber": 59511},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowTypes": [],
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowHasShortcutInputVariables": True,
    "WFWorkflowActions": actions,
}
here = os.path.dirname(os.path.abspath(__file__))
with tempfile.TemporaryDirectory() as folder:
    unsigned = os.path.join(folder, "unsigned.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f)
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", os.path.join(here, "Quasi Relay.shortcut")], check=True)
print("Written: open it to add it to Shortcuts; it syncs to the iPhone through iCloud.")
