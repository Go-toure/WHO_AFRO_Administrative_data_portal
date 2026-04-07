# Replace the duplicate_panel renderUI with this enhanced version:

output$duplicate_panel <- renderUI({
  req(admin_repo())
  all_duplicates <- find_all_duplicates(admin_repo())
  
  if (nrow(all_duplicates) == 0) {
    return(div(class = "alert alert-success", "No duplicates found in the repository."))
  }
  
  div(
    class = "excel-panel",
    div(class = "excel-title", "Duplicate Detection & Resolution"),
    div(
      class = "excel-subtitle",
      paste("Found", nrow(all_duplicates), "records in", length(unique(all_duplicates$duplicate_group)), "duplicate groups")
    ),
    
    # Add action buttons for duplicate resolution
    div(
      style = "margin-bottom: 15px; display: flex; gap: 10px; flex-wrap: wrap;",
      actionButton("keep_oldest_duplicates", "Keep Oldest Entry per Group", 
                   class = "btn-warning", 
                   title = "Keep the record with the earliest Entry_Date in each duplicate group"),
      actionButton("keep_newest_duplicates", "Keep Newest Entry per Group", 
                   class = "btn-warning",
                   title = "Keep the record with the latest Entry_Date in each duplicate group"),
      actionButton("show_merge_dialog", "Merge Selected Duplicates", 
                   class = "btn-info",
                   title = "Select rows from the table below and merge them"),
      actionButton("delete_selected_duplicates", "Delete Selected Duplicates", 
                   class = "btn-danger",
                   title = "Delete the selected duplicate records")
    ),
    
    div(class = "excel-table", DTOutput("all_duplicates_table"))
  )
})

# Add these server-side observers to handle duplicate resolution:

# Keep oldest records per duplicate group
observeEvent(input$keep_oldest_duplicates, {
  req(admin_repo())
  
  showModal(modalDialog(
    title = "Confirm Keep Oldest Records",
    "This will keep only the record with the earliest Entry_Date in each duplicate group. All other duplicates will be removed. This action cannot be undone.",
    footer = tagList(
      modalButton("Cancel"),
      actionButton("confirm_keep_oldest", "Confirm", class = "btn-warning")
    )
  ))
})

observeEvent(input$confirm_keep_oldest, {
  repo <- admin_repo()
  duplicates <- find_all_duplicates(repo)
  
  if (nrow(duplicates) > 0) {
    # For each duplicate group, find the row(s) with the oldest Entry_Date
    to_keep <- duplicates %>%
      group_by(duplicate_group) %>%
      arrange(Entry_Date, ROW_ID) %>%
      slice(1) %>%
      pull(ROW_ID)
    
    to_remove <- setdiff(duplicates$ROW_ID, to_keep)
    
    # Remove the duplicates
    repo <- repo[!(repo$ROW_ID %in% to_remove), , drop = FALSE]
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    
    removeModal()
    showNotification(paste("Removed", length(to_remove), "duplicate records, kept", length(to_keep), "records."), 
                     type = "success")
  }
})

# Keep newest records per duplicate group
observeEvent(input$keep_newest_duplicates, {
  req(admin_repo())
  
  showModal(modalDialog(
    title = "Confirm Keep Newest Records",
    "This will keep only the record with the latest Entry_Date in each duplicate group. All other duplicates will be removed. This action cannot be undone.",
    footer = tagList(
      modalButton("Cancel"),
      actionButton("confirm_keep_newest", "Confirm", class = "btn-warning")
    )
  ))
})

observeEvent(input$confirm_keep_newest, {
  repo <- admin_repo()
  duplicates <- find_all_duplicates(repo)
  
  if (nrow(duplicates) > 0) {
    # For each duplicate group, find the row(s) with the newest Entry_Date
    to_keep <- duplicates %>%
      group_by(duplicate_group) %>%
      arrange(desc(Entry_Date), ROW_ID) %>%
      slice(1) %>%
      pull(ROW_ID)
    
    to_remove <- setdiff(duplicates$ROW_ID, to_keep)
    
    # Remove the duplicates
    repo <- repo[!(repo$ROW_ID %in% to_remove), , drop = FALSE]
    repo <- ensure_rowid_keyid(repo)
    save_repo(repo)
    admin_repo(repo)
    
    removeModal()
    showNotification(paste("Removed", length(to_remove), "duplicate records, kept", length(to_keep), "records."), 
                     type = "success")
  }
})

# Delete selected duplicates
observeEvent(input$delete_selected_duplicates, {
  req(input$all_duplicates_table_rows_selected)
  
  selected_rows <- input$all_duplicates_table_rows_selected
  duplicates <- find_all_duplicates(admin_repo())
  
  if (length(selected_rows) > 0) {
    selected_ids <- duplicates$ROW_ID[selected_rows]
    
    showModal(modalDialog(
      title = "Confirm Delete",
      paste("Are you sure you want to delete", length(selected_ids), "selected duplicate record(s)?"),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_delete_selected_dups", "Delete", class = "btn-danger")
      )
    ))
  }
})

observeEvent(input$confirm_delete_selected_dups, {
  req(input$all_duplicates_table_rows_selected)
  
  selected_rows <- input$all_duplicates_table_rows_selected
  duplicates <- find_all_duplicates(admin_repo())
  selected_ids <- duplicates$ROW_ID[selected_rows]
  
  repo <- admin_repo()
  repo <- repo[!(repo$ROW_ID %in% selected_ids), , drop = FALSE]
  repo <- ensure_rowid_keyid(repo)
  save_repo(repo)
  admin_repo(repo)
  
  removeModal()
  showNotification(paste("Deleted", length(selected_ids), "duplicate record(s)"), type = "success")
})

# Merge duplicates dialog
observeEvent(input$show_merge_dialog, {
  req(input$all_duplicates_table_rows_selected)
  
  selected_rows <- input$all_duplicates_table_rows_selected
  duplicates <- find_all_duplicates(admin_repo())
  
  if (length(selected_rows) < 2) {
    showNotification("Please select at least 2 duplicate records to merge.", type = "warning")
    return()
  }
  
  selected_records <- duplicates[selected_rows, , drop = FALSE]
  groups <- unique(selected_records$duplicate_group)
  
  if (length(groups) > 1) {
    showNotification("Please select records from the same duplicate group only.", type = "warning")
    return()
  }
  
  showModal(modalDialog(
    title = "Merge Duplicate Records",
    size = "l",
    div(
      p("Select which values to keep for each column when merging these duplicate records:"),
      br(),
      DTOutput("merge_preview_table")
    ),
    footer = tagList(
      modalButton("Cancel"),
      actionButton("confirm_merge", "Merge Selected", class = "btn-primary")
    )
  ))
  
  # Store the selected records for merging
  session$userData$merge_records <- selected_records
})

output$merge_preview_table <- renderDT({
  req(session$userData$merge_records)
  records <- session$userData$merge_records
  
  # Create a comparison table
  comparison <- data.frame(
    Column = names(records),
    stringsAsFactors = FALSE
  )
  
  # Add columns for each record's value
  for (i in 1:nrow(records)) {
    comparison[[paste0("Record_", i, " (ROW_ID: ", records$ROW_ID[i], ")")]] <- sapply(names(records), function(col) {
      val <- records[i, col]
      if (is.na(val)) return("NA")
      if (inherits(val, "Date")) return(as.character(val))
      return(as.character(val))
    })
  }
  
  # Add select input column for choosing which value to keep
  comparison$`Keep Value From` <- sapply(1:nrow(comparison), function(i) {
    col_name <- comparison$Column[i]
    if (col_name %in% c("ROW_ID", "KEY_ID", "Entry_Date")) {
      return("Auto (Newest)")
    }
    return("Auto (First Non-NA)")
  })
  
  datatable(comparison, 
            options = list(pageLength = 50, scrollX = TRUE),
            rownames = FALSE)
}, server = TRUE)

observeEvent(input$confirm_merge, {
  req(session$userData$merge_records)
  records <- session$userData$merge_records
  repo <- admin_repo()
  
  # Merge strategy: take first non-NA value, prioritize newer Entry_Date if available
  merged_record <- records[1, , drop = FALSE]
  
  for (col in names(records)) {
    if (col %in% c("ROW_ID", "KEY_ID")) {
      next  # Skip these, they'll be regenerated
    }
    
    # Get non-NA values from all records
    values <- records[[col]]
    values <- values[!is.na(values) & values != ""]
    
    if (length(values) > 0) {
      merged_record[1, col] <- values[1]  # Take first non-NA
    }
  }
  
  # Update Entry_Date to current date
  merged_record$Entry_Date <- Sys.Date()
  
  # Remove all duplicate records and add the merged one
  repo <- repo[!(repo$ROW_ID %in% records$ROW_ID), , drop = FALSE]
  merged_record <- ensure_rowid_keyid(merged_record)
  repo <- bind_rows(repo, merged_record)
  repo <- remove_duplicates_from_repo(repo)
  repo <- ensure_rowid_keyid(repo)
  
  save_repo(repo)
  admin_repo(repo)
  
  removeModal()
  session$userData$merge_records <- NULL
  
  showNotification(paste("Merged", nrow(records), "records into 1 record"), type = "success")
})

# Update the all_duplicates_table to enable selection
output$all_duplicates_table <- renderDT({
  req(admin_repo())
  duplicates <- find_all_duplicates(admin_repo())
  if (nrow(duplicates) == 0) return(datatable(data.frame(Message = "No duplicates found")))
  
  datatable(
    duplicates,
    selection = "multiple",  # This enables row selection
    filter = "top",
    extensions = c("Scroller", "KeyTable", "Buttons"),
    options = list(
      pageLength = 10,
      scrollX = TRUE,
      scrollY = 520,
      scroller = TRUE,
      deferRender = TRUE,
      processing = TRUE,
      keys = TRUE,
      dom = "Bfrtip",
      buttons = c("copy", "csv", "excel")
    )
  )
}, server = TRUE)