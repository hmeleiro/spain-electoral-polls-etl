root <- normalizePath(file.path(dirname(getwd()), ".."), mustWork = FALSE)
if (!file.exists(file.path(root, "R", "utils.R"))) {
  root <- normalizePath(getwd(), mustWork = FALSE)
}
source(file.path(root, "R", "utils.R"))
source_project_r_files(root)
