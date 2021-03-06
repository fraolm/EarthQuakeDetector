#Fraol Dechasa & Pawan Subedi


library(RCurl)
library(RJSONIO)
library(shiny)
library(leaflet)
library(RColorBrewer)
library(jsonlite)

# aquire the URLS form the web
HourlyUpdate <- getURL("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_hour.geojson")
DailyUpdate <- getURL("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_day.geojson")
WeeklyUpdate <- getURL("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson")
Update30Days <- getURL("https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_month.geojson")

#Create a vector that containes  the URLs
content <- c(HourlyUpdate, DailyUpdate, WeeklyUpdate, Update30Days)


# function that process the data sets.
# The function takes a string and assigns URL according to the condition.
getQuakes<-function(str){
  if(str == "Past 30 Days"){
    URL = Update30Days
  }
  else if(str == "Past Week"){
    URL = WeeklyUpdate
  }
  else if(str == "Past Day"){
    URL = DailyUpdate
  }
  else if(str == "Past Hour"){
    URL = HourlyUpdate
  }
  #Repeat the data collection and manipulation to obtain the dataframe to operate on
  data = jsonlite::fromJSON(URL, flatten = TRUE)
  size = dim(data$features[1])[1]
  
  dataFrame = data.frame()
  for (i in rep(1:size))
  {
    tempCoords = data$features$geometry.coordinates[[i]]
    record = data.frame(tempCoords[2], tempCoords[1], tempCoords[3], data$features$properties.mag[i])
    dataFrame = rbind(dataFrame, record)
  }
  colnames(dataFrame) = c("lat", "long", "depth", "mag")
  return(dataFrame)
}
dataFrame <- getQuakes("Past 30 Days")

ui <- bootstrapPage(
  tags$style(type = "text/css", "html, body {width:100%;height:100%}"),
  leafletOutput("map", width = "100%", height = "100%"),
  absolutePanel(top = 10, right = 10,
                sliderInput("range", "Magnitudes", min(dataFrame$mag), max(dataFrame$mag),
                            value = range(dataFrame$mag), step = 0.1
                ),
                selectInput("colors", "Color Scheme",
                            rownames(subset(brewer.pal.info, category %in% c("seq", "div")))
                ),
                checkboxInput("legend", "Show Legend", TRUE),
                selectInput("content", "TimeFrame", list("Past Hour", "Past Day", "Past Week", "Past 30 Days"), selected = "Past 30 Days", multiple = FALSE)
  )
)


server <- function(input, output, session)
{
  # Reactive expression for the data subsetted to what the user selected
  filteredData <- reactive({
    getQuakes(input$content)[getQuakes(input$content)$mag >= input$range[1] & getQuakes(input$content)$mag <= input$range[2],]
  })
  
  # This reactive expression represents the palette function,
  # which changes as the user makes selections in UI.
  colorpal <- reactive({
    colorNumeric(input$colors, getQuakes(input$content)$mag)
  })
  
  output$inp<-({
    renderText(input$content)
  })
  
  output$map <- renderLeaflet({
    # Use leaflet() here, and only include aspects of the map that
    # won't need to change dynamically (at least, not unless the
    # entire map is being torn down and recreated).
    leaflet(data = getQuakes(input$content)) %>% addTiles() %>%
      fitBounds(~min(long), ~min(lat), ~max(long), ~max(lat))
  })
  
  # Incremental changes to the map (in this case, replacing the
  # circles when a new color is chosen) should be performed in
  # an observer. Each independent set of things that can change
  # should be managed in its own observer.
  observe({
    pal <- colorpal()
    
    leafletProxy("map", data = filteredData()) %>%
      clearShapes() %>%
      addCircles(radius = ~10^mag/10, weight = 2, color = "#888888",
                 fillColor = ~pal(mag), fillOpacity = 0.8, popup = ~paste(mag)
      )
  })
  
  # Use a separate observer to recreate the legend as needed.
  observe({
    proxy <- leafletProxy("map", data = getQuakes(input$content))
    
    # Remove any existing legend, and only if the legend is  
    # enabled, create a new one.
    proxy %>% clearControls()
    if (input$legend) {
      pal <- colorpal()
      proxy %>% addLegend(position = "bottomleft",
                          pal = pal, values = ~mag
      )
    }
  })
  observe({
    val <- input$range
    # Control the value, min, max, and step.
    # When the input is even the size is steped 2 and steps 1 when the value is odd.
    updateSliderInput(session, "range",
                      min = min(getQuakes(input$content)$mag), max = max(getQuakes(input$content)$mag))
  })
}

shinyApp(ui, server)

