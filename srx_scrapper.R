library(magrittr)
library(dplyr)
library(rvest)

host_url = 'https://www.srx.com.sg'

# this function will fetch all listing nodes and return them as a list
fetch_property_nodes = function(page) {
  url = paste(host_url, "/search/sale/residential?page=", page, sep = "")
  srx_html = read_html(url)
  listing = html_nodes(srx_html, ".listingDetailTitle")
  if(length(listing) == 0)
    return(c('Done'))
  return(listing)
}

# this is just a try-catch wrapper on top of ^
trycatch_fetch_property_notes = function(n) {
  result = tryCatch({
    return (fetch_property_nodes(n))
  }, warning = function(n) {
    print(paste("Warning in crawling the ", n, "th page of SRX", sep = ""))
  }, error = function(n) {
    print(paste("Error in crawling the ", n, "th page of SRX", sep = ""))
    return(c('Done'))
  }, finally = function(n) { 
  })
  return (result)
}

# this function takes in the node's 1) details 2) facilities and 3) agent name and spits out a single-row df for entry
get_df_from_node_list = function(listing_info_node, facilities_info_node, agent_name) {
  labels = listing_info_node %>% html_children %>% `[`(c(T, F)) %>% html_text %>% takeout_last_char                   
  values = listing_info_node %>% html_children %>% `[`(c(F, T)) %>% html_text %>% remove_tabs                         
  facilities = facilities_info %>% html_children %>% html_text %>% remove_tabs %>% paste(collapse=' | ')              
  
  data_list = list()
  data_list[labels] = values
  data_list['Facilities'] = facilities
  data_list['Agent'] = agent_name
  
  data_list %>% as.data.frame
}

# simple function to remove spaces of all kinds
remove_tabs = function(x) {
  gsub("([\t]|[\r\n])", "", x)
}

# simple function to remove the colon from the label
takeout_last_char = function(x) {
  x %>% substr(1, nchar(x) - 1)
}

# the real script, 
# 1. calls a query for each page
# 2. for every listing, call a query to pull data about listing
# 3. feeds listing data into get_df_from_node_list to get a single row df
# 4. stitch df into main df
# 5. breaks when done
#
# this function can be further refactored for SLAP 

n = 1L
prop_df = data.frame()

while(n < 100000){ # 100,000 is used instead of TRUE so that even if the code fails, it does not go on forever
  property = trycatch_fetch_property_notes(n)
  
  if (property[1] == 'Done') {
    break
  }
  
  for (i in 1:length(property)) {
    listing_url = paste(host_url, html_attr(property[i], 'href'), sep="")
    listing_html = read_html(listing_url)
    listing_data = html_nodes(listing_html, '.listing-about-main')              
    listing_info = html_nodes(listing_data[1], 'p')                                      
    facilities_info = listing_data[2]                                           
    agent_name = listing_html %>% html_node('.featuredAgentName') %>% html_text
    row_df = get_df_from_node_list(listing_info, facilities_info, agent_name)
    prop_df = suppressWarnings(bind_rows(prop_df, row_df))
  }
  
  n = n + 1
}

prop_df %>% head

prop_df %>% write.csv(file='srxx.csv')