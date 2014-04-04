require 'open-uri'

class WdfidfController < ApplicationController
  
  def index
    
  end
 
  
  def analyze
    keyword = params[:keyword]   
    @view_hash = {}
    
    serps = scrape_serps(keyword)
    keywords_nis = keyword_counter_hash(keyword, serps)
    
    index = 1
    
    serps.each do |url|
      content_hash = get_content(url)
      
      content_hash['keywords'] = analyze_content(content_hash[:result_text], content_hash[:count], keywords_nis)
      content_hash['index'] = index
      
      index = index + 1
      
      @view_hash[url.to_s] = content_hash
    end 

    render :index  
  end 
  
  private
  
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
  
  def keyword_count_method(result_hash, content)
    uniq_content = content.uniq
    keys = result_hash.keys
    
    uniq_content.each do |keyword|
      if keys.include?(keyword)
        counter = result_hash[keyword]
        result_hash[keyword] = counter + 1
      else
        result_hash[keyword] = 1
      end
    end
    
    result_hash
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
      
        keyword_hash[keyword] = { 
          amount: amount,
          wdf: wdf,
          wdf_idf: wdf_idf
        }
      end
    end
  
    keyword_hash
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
    doc = Nokogiri::HTML(open(url))
    uri = URI("#{url}")
    url_host = uri.host
   
   
   
    # Javascript entfernen
    doc.css('script').remove
    doc.xpath("//@*[starts-with(name(),'on')]").remove
   
    #puts "doc: #{doc}"
    #Auslesen der Meta-Tags und Anzahl der Zeichen inklusive Leerzeichen
    title = get_title(doc)

    title_count = title.length

    description = get_description(doc) 
    description_count = description.length

    #Auslesen des body-Tags und Umwandlung in Kleinbuchstaben
    html = doc.at('body').inner_text.downcase + title.downcase + description.downcase
   
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
   # prng = Random.new()
   # random = prng.rand(0.5..1.5) 
   # random = random.round(1)
   # sleep(random)
  #  doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{tmp_keyword}","User-Agent" => "Ruby/#{RUBY_VERSION}"))
   # results_number = doc.xpath('//div[@id="resultStats"]').text
    #results_number.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    #serp_amount = results_number.scan(/\d+/).join("").to_i
    serp_amount = 450000
    return serp_amount
  end
  
  def get_wdf(wdf_keyword, freq, l)
     wdf = ((Math.log((freq + 1), 2)) /  (Math.log(l,2)))
     wdf = wdf.round(4)   
     return wdf
  
  end
  
  def get_idf(idf_keyword, ni)
    nd = get_serp_amount(idf_keyword)
    number =  (nd) / (ni)
    idf = Math.log(1 + number, 10)
    idf = idf.round(4)  
    return idf 
  end
end
