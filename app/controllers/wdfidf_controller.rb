require 'open-uri'

class WdfidfController < ApplicationController
  
  def index
    
  end
 
  
  def analyze
    keyword = params[:keyword]   
    @view_hash = {}
    keyword_hash = {}
    serps = scrape_serps(keyword)
    #Berechnung des ni pro Keyword - Anzahl der Urls, die das Keyword verwenden
    keywords_nis = keyword_counter_hash(keyword, serps)
    
    index = 1
    
    serps.each do |url|
      content_hash = get_content(url)
      
      content_hash['keywords'] = analyze_content(content_hash[:result_text], content_hash[:count], keywords_nis)
      content_hash['index'] = index
      
      keyword = content_hash['keywords'].keys
      
      gon_ausgabe(index, keyword_hash)
   
      index = index + 1
      @view_hash[url.to_s] = content_hash
    end 
    
    index = 1
    
    render :index  
  end 
  
  private
  
  def gon_ausgabe(index, keyword)
    case index
    when 1
      gon.term_1 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_1
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_1 = array
    when 2
      gon.term_1 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_2
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_2 = array
    when 3
      gon.term_3 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_3
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_3 = array
    when 4
      gon.term_4 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_4
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_4 = array
    when 5
      gon.term_5 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_5
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_5 = array
    when 6
      gon.term_6 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_6
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_6 = array
    when 7
      gon.term_7 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_7
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_7 = array
    when 8
      gon.term_8 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_8
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_8 = array
    when 9
      gon.term_9 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_9
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_9 = array
    when 10
      gon.term_10 = keyword
      #Gon Dateien für Anzeige anpassen
      array =  []
      my_array = gon.term_10
      my_array.each_slice(1) do |value|
         array << {:keyword => value[0]}
      end 
      gon.term_10 = array    
    else
         
    end
         binding.pry
  end
 
  def keyword_counter_hash(keyword, serps)
    keyword_counter = {}
    
    serps.each do |url|
      content = get_content(url)
      
      text = content[:result_text]
      uniq_content = text.uniq
      keys = keyword_counter.keys
    
      uniq_content.each do |keyword|
        if keys.include?(keyword)
          counter = keyword_counter[keyword]
          keyword_counter[keyword] = counter + 1
        else
          keyword_counter[keyword] = 1
        end
      end
    end 
    
    keyword_counter
  end
  
  def analyze_content(result_text, word_count, keyword_nis)
    # Ermitteln der Häufigkeit jedes Terms aus einem Dokument
    # Rückgabe (term,anzahl)
    term_counts = result_text.group_by{|i| i}.map{|k,v| [k, v.count] } 
    
    keyword_hash = {}
    
    term_counts.each do |keyword_array|
      keyword = keyword_array.first
      amount = keyword_array.last
      
      if amount > 1
        ni = keyword_nis[keyword]
      
        idf = get_idf(keyword, ni)
        wdf = get_wdf(keyword, amount, word_count)
      
        wdf_idf = wdf * idf
        wdf_idf = wdf_idf.round(4) 
        
        keyword_hash[keyword] = { 
          amount: amount,
          wdf: wdf,
          wdf_idf: wdf_idf
        }
      end
    end
  
    keyword_hash
  end
  
  def get_title(doc)
    return doc.xpath('//html/head/title').text 
  end
  
  def get_description(doc)
    return doc.xpath('//head/meta[@name = "description"]/@content').text 
  end
  
  def get_content(url)
    doc = Nokogiri::HTML(open(url))
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
    html = doc.at('body').inner_text
    if html.empty?
      redirect_to root_url, alert: "You're stuck here!"
    else
      html = html.downcase + title.downcase + description.downcase
      
      # String mit allen gefundenen Termen 
      text = html.scan(/\p{Alpha}+|\d+(?:[\.\-\/]\d+)*/) 
    
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
  end 

  def scrape_serps(keyword)
    tmp_keyword = keyword.dup
    tmp_keyword = get_keyword_out_umlauts_google(tmp_keyword)
    #Scrapen der Suchergebnisse von Google
    url_list = []
    # Bei Eingabe von Umlauten nach Google Abfrage ändern
    doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{tmp_keyword}"))
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
      url_list
  end

  def get_keyword_out_umlauts_google(keyword)
     # Bei Eingabe von Umlauten nach Google Abfrage ändern
    keyword.gsub!('ä', '%C3%A4')
    keyword.gsub!('ö', '%C3%B6')
    keyword.gsub!('ü', 'C3%BC')
    keyword.gsub!('ß', '%C3%9F')
    keyword.gsub!('Ä', '%C3%84')
    keyword.gsub!('Ö', '%C3%96')
    keyword.gsub!('Ü', '%C3%9')
    keyword
  end
  
  def get_serp_amount(keyword)
    tmp_keyword = keyword.dup
    tmp_keyword = get_keyword_out_umlauts_google(tmp_keyword)
    doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{tmp_keyword}","User-Agent" => "Ruby/#{RUBY_VERSION}"))
    results_number = doc.xpath('//div[@id="resultStats"]').text
    results_number.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    serp_amount = results_number.scan(/\d+/).join("").to_i
    serp_amount
  end
  
  def get_wdf(wdf_keyword, freq, l)
     wdf = ((Math.log((freq + 1), 2)) /  (Math.log(l,2)))
     wdf = wdf.round(4)   
     wdf
  
  end
  
  def get_idf(idf_keyword, ni)
    # nd = get_serp_amount(idf_keyword)
    nd = 4500000
    number =  (nd) / (ni)
    idf = Math.log(1 + number, 10)
    idf = idf.round(4)  
    idf 
  end
end
