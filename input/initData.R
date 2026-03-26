library(dplyr)

MAX_LB_ROWS_PER_SUBJECT <- 1000
MAX_DATACHG_ROWS_PER_SUBJECT <- 1000

cap_rows_per_group <- function(df, group_col, order_cols, max_rows) {
    df %>%
        arrange(across(all_of(c(group_col, order_cols)))) %>%
        group_by(across(all_of(group_col))) %>%
        slice_head(n = max_rows) %>%
        ungroup()
}

lData <- list(
    Raw_SUBJ = gsm.core::lSource$Raw_SUBJ,
    Raw_AE = gsm.core::lSource$Raw_AE,
    Raw_PD = gsm.core::lSource$Raw_PD %>%
        rename(
            subjid = subjectenrollmentnumber,
            dvdecod = crocategory,
            dvterm = description,
            dvdtm = deviationdate
        ),
    Raw_LB = gsm.core::lSource$Raw_LB %>%
        cap_rows_per_group(
            group_col = "subjid",
            order_cols = c("lb_dt", "visnam", "lbtstnam", "battrnam"),
            max_rows = MAX_LB_ROWS_PER_SUBJECT
        ),
    Raw_PK = gsm.core::lSource$Raw_PK %>%
        rename(
            visit = foldername
        ),
    Raw_STUDCOMP = gsm.core::lSource$Raw_STUDCOMP,
    Raw_SDRGCOMP = gsm.core::lSource$Raw_SDRGCOMP,
    Raw_DATACHG = gsm.core::lSource$Raw_DATACHG %>%
        cap_rows_per_group(
            group_col = "subjectname",
            order_cols = c("visit_date", "visnam", "form", "field"),
            max_rows = MAX_DATACHG_ROWS_PER_SUBJECT
        ) %>%
        rename(subject_nsv = subjectname),
    Raw_DATAENT = gsm.core::lSource$Raw_DATAENT %>%
        rename(subject_nsv = subjectname),
    Raw_QUERY = gsm.core::lSource$Raw_QUERY %>%
        rename(subject_nsv = subjectname),
    Raw_ENROLL = gsm.core::lSource$Raw_ENROLL,
    Raw_SITE = gsm.core::lSource$Raw_SITE %>%
        rename(
            studyid = protocol,
            invid = pi_number,
            InvestigatorFirstName = pi_first_name,
            InvestigatorLastName = pi_last_name,
            City = city,
            State = state,
            Country = country
        ),
    Raw_STUDY = gsm.core::lSource$Raw_STUDY %>%
        rename(studyid = protocol_number)
)

# add a loop to write csv files 
out_dir <- if (basename(getwd()) == "input") "." else "input"

for(nm in names(lData)) {
    df <- lData[[nm]]
    if (is.data.frame(df)) {
        f <- file.path(out_dir, paste0(nm, ".csv"))
        write.csv(df, f, row.names = FALSE)
        cat(nm, ":", nrow(df), "x", ncol(df), "->", f, "\n")
    }
}