GetSubset <-
function(Lat, Long, Product, Band, StartDate, EndDate, KmAboveBelow, KmLeftRight)
{
  if(length(Product) != 1) stop("Incorrect length of Product input. Give only one data product at a time.")

  if(length(Band) != 1) stop("Incorrect length of Band input. Give only one data band at a time.")

  if(!is.numeric(Lat) | !is.numeric(Long)) stop("Lat and Long inputs must be numeric.")

  if(length(Lat) != 1 | length(Long) != 1) stop("Incorrect number of Lats and Longs supplied (only 1 coordinate allowed).")

  if(abs(Lat) > 90 | abs(Long) > 180) stop("Detected a lat or long beyond the range of valid coordinates.")

  getsubset.xml <- paste('
    <soapenv:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
             xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:mod="http://daacmodis.ornl.gov/MODIS_webservice">
                         <soapenv:Header/>
                         <soapenv:Body>
                         <mod:getsubset soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
                         <Latitude xsi:type="xsd:float">', Lat, '</Latitude>
                         <Longitude xsi:type="xsd:float">', Long, '</Longitude>
                         <Product xsi:type="xsd:string">', Product, '</Product>
                         <Band xsi:type="xsd:string">', Band, '</Band>
                         <MODIS_Subset_Start_Date xsi:type="xsd:string">', StartDate, '</MODIS_Subset_Start_Date>
                         <MODIS_Subset_End_Date xsi:type="xsd:string">', EndDate, '</MODIS_Subset_End_Date>
                         <Km_Above_Below xsi:type="xsd:string">', KmAboveBelow, '</Km_Above_Below>
                         <Km_Left_Right xsi:type="xsd:string">', KmLeftRight, '</Km_Left_Right>
                         </mod:getsubset>
                         </soapenv:Body>
                         </soapenv:Envelope>',
                         sep = "")

  header.fields <- c(Accept = "text/xml",
                    Accept = "multipart/*",
                    'Content-Type' = "text/xml; charset=utf-8",
                    SOAPAction = "")

  reader <- basicTextGatherer()
  header <- basicTextGatherer()

  curlPerform(url = "http://daacmodis.ornl.gov/cgi-bin/MODIS/GLBVIZ_1_Glb_subset/MODIS_webservice.pl",
              httpheader = header.fields,
              postfields = getsubset.xml,
              writefunction = reader$update,
              verbose = FALSE)

  # Check the server is not down by insepcting the XML response for internal server error message.
  if(grepl("Internal Server Error", reader$value())){
    stop("Web service failure: the ORNL DAAC server seems to be down, please try again later.
         The online subsetting tool (http://daac.ornl.gov/cgi-bin/MODIS/GLBVIZ_1_Glb/modis_subset_order_global_col5.pl)
         will indicate when the server is up and running again.")
  }

  xmlres <- xmlRoot(xmlTreeParse(reader$value()))
  modisres <- xmlSApply(xmlres[[1]],
                        function(x) xmlSApply(x,
                            function(x) xmlSApply(x,
                                function(x) xmlSApply(x,xmlValue))))

  if(colnames(modisres) == "Fault"){
    if(length(modisres['faultstring.text', ][[1]]) == 0){
      stop("Downloading from the web service is currently not working. Please try again later.")
    }
    stop(modisres['faultstring.text', ])
  } else{
    modisres <- as.data.frame(t(unname(modisres[-c(7,11)])))
    names(modisres) <- c("xll", "yll", "pixelsize", "nrow", "ncol", "band", "scale", "lat", "long", "subset")
    return(modisres)
  }
}