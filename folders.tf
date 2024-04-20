resource "google_folder" "network_folder" {
  display_name = var.folder_display_name
  parent          = var.root_node
 # parent       = "folders/${var.nbss_main_folder_id}"
}

data "google_folder" "my_folder_info" {
   folder = google_folder.network_folder.id
}