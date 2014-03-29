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
    serp_amount = get_serp_amount(keyword)
    render :index  
    
  end 
  
 
  
  
  private
  
  def analyze_content(content)
    # Ermitteln der Häufigkeit jedes Terms aus einem Dokument
    # Rückgabe (term,anzahl)
    term = content[:result_text]
    term_counts = term.group_by{|i| i}.map{|k,v| [k, v.count] } 

    return{
      :url_host => content[:url_host],
      :url => content[:url],
      :title => content[:title],
      :title_count => content[:title_count],
      :description => content[:description], 
      :description_count => content[:description_count],
      :term_count_in_text_and_amount => term_counts,
      :count => content[:count]
    }
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
   
    #Auslesen Meta-Tags und Länge
    title = get_title(doc)
    title_count = title.length
    description = get_description(doc) 
    description_count = description.length
   
    #Auslesen des body-Tags und umwandlung in kleinbuchstaben
    html = doc.at('body').inner_text.downcase + title.downcase + description.downcase
   
    # String mit nur Termen aus Buchstaben  
    #text  = html.scan(/\p{alnum}[a-zA-Z-]+/)  
    # String mit allen Termen
    #text = html.scan(/\p{Alnum}+/)
    text = html.scan(/\p{alpha}+|\d+(?:[\.\-\/]\d+)*/) 
    #http://solariz.de/de/downloads/6/german_enhanced_stopwords.htm
    #Bereinigte Wortliste
    result_text = text - config.STOPWORDS
    
    #Anzahl Wörter
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

  def get_serp_amount(keyword)
    doc = Nokogiri::HTML(open("https://www.google.de/search?q=#{keyword}"))
    results_number = doc.xpath('//div[@id="resultStats"]').text
    results_number.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
    serp_amount = results_number.scan(/\d+/).join("").to_i
    return :serp_amount
  end
  
  def get_wdf(url, keyword, freq, l)
     wdf = log2(freq + 1) /  log2(l)
     return wdf
  end
  
  def get_idf(url, keyword, nd, ni)
     idf = log10(1 + nd / ni)
     return idf
  end
  
  def get_wdf_idf(wdf , idf)
     return wdf*idf
  end
end
