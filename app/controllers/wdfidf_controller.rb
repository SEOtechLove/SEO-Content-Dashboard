require 'open-uri'


class WdfidfController < ApplicationController
  
  def index
    
  end
 
  
  def analyze
    keyword = params[:keyword]
    @view = []
    serps = scrape_serps(keyword)
    serps.each do |url|
      content = get_content(url)
      @view << analyze_content(content)
    end
    render :index
    
  end 
  

  private
  
  def analyze_content(content)
    # Ermitteln der Häufigkeit jedes Terms aus einem Dokument
    # Rückgabe (term,anzahl)
    term = content[:result_text]
    term_counts = term.group_by{|i| i}.map{|k,v| [k, v.count] } 
    term_counts_min = filter_terms(term_counts, 3)

    # Wdf pro Term berechnen
    # Rückgabe (term,wdf)
    count = content[:count]
    wdf_term = term_counts_min.map {|k, v| get_wdf(k, v, count) } 
    
    # IDF pro Term berechnen
    idf_term = term_counts_min.map {|k, v| get_idf(k) }
    
    # WDF * IDF Berechnung
    #wdf_idf = idf_term.map
    
    return{
     # :url_host => content[:url_host],
       :url => content[:url],
       :title => content[:title],
    #  :title_count => content[:title_count],
       :description => content[:description], 
    #  :description_count => content[:description_count],
       :term_count_filtered => term_counts_min,
       :wdf_term => wdf_term,
       :idf_term => idf_term,
       #:wdf_idf => wdf_idf
       :count=> content[:count]
    }
  end
  
  def filter_terms(term_counts, min_amount)
    #Filtert alle Terme, die weniger als min_amount vorkommen
   term_counts_min = term_counts.delete_if{|k,v| v < min_amount}
   return term_counts_min
  end
  
  def get_title(doc)
    return doc.xpath('//html/head/title').text 
  end
  
  def get_description(doc)
    return doc.xpath('//head/meta[@name = "description"]/@content').text 
  end
  
  def get_content(url)
    doc = Nokogiri::HTML(open(url ,"User-Agent" => "Ruby/#{RUBY_VERSION}"))
    uri = URI("#{url}")
    url_host = uri.host
   
    # Javascript entfernen
    doc.css('script').remove
    doc.xpath("//@*[starts-with(name(),'on')]").remove
   
    #Auslesen der Meta-Tags und Anzahl der Zeichen inklusive Leerzeichen
    title = get_title(doc)
    title_count = title.length
    
    description = get_description(doc) 
    description_count = description.length
   
    #Auslesen des body-Tags und Umwandlung in Kleinbuchstaben
    html = doc.at('body').inner_text.downcase + title.downcase + description.downcase
   
    # String mit allen gefundenen Termen  
    text = html.scan(/\p{alpha}+|\d+(?:[\.\-\/]\d+)*/) 
    
    #Terme mit Hilfe von Stopwort-Liste bereinigen (Stopwords-Liste: #http://solariz.de/de/downloads/6/german_enhanced_stopwords.htm + eigene)
    result_text = text - config.STOPWORDS
    
    #Anzahl Terme innerhalb eines Dokumentes
    count = result_text.count
    
    return {
      :url_host => url_host,
      :url => url,
      :title => title,
      :title_count => title_count,
      :description => description,
      :description_count => description_count,
      :result_text => result_text,
      :count => count}
  end 

  def scrape_serps(keyword)
    #Scrapen der Suchergebnisse von Google
    url_list = []
    # Bei Eingabe von Umlauten nach Google Abfrage ändern
    doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{keyword}"))
    doc.xpath('//*[contains(concat( " ", @class, " " ), concat( " ", "r", " " ))]//a/@href').each do |i|
      result = i.inner_text
      if result.include?("/url?q=")
            result = result.split("&sa")[0]
            result = result.split("q=")[1]
      else
            result = nil
      end    
      url_list << result
    end
      url_list.compact! 
    return url_list
  end

  def get_keyword_out_umlauts_google(keyword)
     # Bei Eingabe von Umlauten nach Google Abfrage ändern
    keyword.gsub!('ä', '%C3%A4')
    keyword.gsub!('ö', '%C3%B6')
    keyword.gsub!('ü', 'C3%BC')
    keyword.gsub!('ß', '%C3%9F')
    
    return keyword
  end
  
  def get_serp_amount(keyword)
    tmp_keyword = keyword.dup
    tmp_keyword = get_keyword_out_umlauts_google(tmp_keyword)
    #Delay, um Google IP-Ban vorzubeugen
    #prng = Random.new()
    #random = prng.rand(0.5..1.5) 
    #random = random.round(1)
    #sleep(random)
    doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{tmp_keyword}"))
    results_number = doc.xpath('//div[@id="resultStats"]').text
    results_number.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    serp_amount = results_number.scan(/\d+/).join("").to_i
    return serp_amount
  end
  
  def get_wdf(wdf_keyword, freq, l)
     wdf = ((Math.log((freq + 1), 2)) /  (Math.log(l,2)))
     wdf = wdf.round(4)
     return {
      :wdf_keyword => wdf_keyword, 
      :wdf => wdf
    }
  end
  
  def get_idf(idf_keyword)
    
     nd = get_serp_amount(idf_keyword)
     ni = 6
     number =  (nd) / (ni)
     idf = Math.log(1 + number, 10)
     return {
       :idf_keyword => idf_keyword, 
       :idf => idf
     }
  end
  
end
