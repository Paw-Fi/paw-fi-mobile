#!/usr/bin/env python3

import json
import sys
import os

def remove_duplicate_keys(file_path):
    """Remove duplicate keys from ARB file, keeping only the first occurrence"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # List of keys to remove (from the cleaning process)
    keys_to_remove = [
        "active",
        "addANote", 
        "alertThreshold",
        "alertThresholdHelper",
        "alertThresholdRange",
        "alertThresholds",
        "amount",
        "budgetName",
        "byCategory",
        "cancel",
        "category",
        "categoryEducation",
        "categoryEntertainment", 
        "categoryFood",
        "categoryGroceries",
        "categoryHousing",
        "categoryIncome",
        "categoryShopping",
        "categoryTransport",
        "categoryTravel",
        "categoryUtilities",
        "collaborateOnFinancialDecisions",
        "confirmDeleteBudget",
        "confirmExpense",
        "copyLink",
        "createHousehold",
        "currency",
        "date",
        "deleteBudget",
        "details",
        "done",
        "editAmount",
        "editNotes",
        "email",
        "enterValidAmountGreaterThan0",
        "enterYourInvitationLinkToJoin",
        "errorLoadingExpenses",
        "errorLoadingHouseholds",
        "errorLoadingMembers",
        "expenseDetails",
        "expenseSaved",
        "expenseSavedAndShared",
        "expiresSoon",
        "failedToLoadImage",
        "failedToSave",
        "failedToUpdateBudget",
        "goToHousehold",
        "household",
        "inactive",
        "invalidVerificationCode",
        "invitationValidUntil",
        "joinAHousehold",
        "joinHousehold",
        "joinWithInvite",
        "loadingHouseholdMembers",
        "member",
        "nameMaxLength",
        "next",
        "noExpensesYet",
        "notes",
        "overview",
        "owner",
        "pasteInvitationLink",
        "pasteTheInvitationLinkYouReceived",
        "peek30DaysAhead",
        "pleaseEnterAValidInvitationLink",
        "pleaseEnterAnInvitationLink",
        "pleaseEnterValidAmount",
        "receipt",
        "retry",
        "saveExpense",
        "selectHouseholdToConfigureSplit",
        "settings",
        "shareWithHousehold",
        "spent",
        "split",
        "thisWillOnlyTakeAMoment",
        "time",
        "today",
        "trackHouseholdFinancialHealth",
        "transactions",
        "unableToJoin",
        "validating",
        "viewSharedBudgetsAndExpenses",
        "warningThreshold",
        "warningThresholdHelper",
        "warningThresholdLessThanAlert",
        "warningThresholdRange",
        "welcomeAboard",
        "welcomeToHouseholds",
        "whatYoullGet",
        "yesterday",
        "youreNowPartOfTheHousehold"
    ]
    
    lines = content.split('\n')
    result_lines = []
    seen_keys = set()
    
    for line in lines:
        # Check if this line contains a key to remove
        should_remove = False
        for key in keys_to_remove:
            # Look for pattern:  "key": 
            if f'"{key}":' in line:
                should_remove = True
                break
        
        # Also handle the @nameMaxLength special case
        if '"@nameMaxLength":' in line:
            should_remove = True
        
        if not should_remove:
            result_lines.append(line)
    
    # Write the cleaned content back
    cleaned_content = '\n'.join(result_lines)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(cleaned_content)
    
    print(f"Removed duplicate keys from {os.path.basename(file_path)}")

def main():
    base_path = "/Users/charles/side-projects/Moneko/moneko-mobile/lib/l10n"
    files_to_clean = [
        "app_es.arb",
        "app_fr.arb",
        "app_it.arb", 
        "app_ja.arb",
        "app_kr.arb",
        "app_nl.arb",
        "app_pks.arb",
        "app_ru.arb",
        "app_uk.arb"
    ]
    
    for filename in files_to_clean:
        file_path = os.path.join(base_path, filename)
        if os.path.exists(file_path):
            remove_duplicate_keys(file_path)
        else:
            print(f"File not found: {file_path}")

if __name__ == "__main__":
    main()
