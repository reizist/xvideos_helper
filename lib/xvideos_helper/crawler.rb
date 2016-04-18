# coding: utf-8
require 'open-uri'
require "nokogiri"

module XvideosHelper
  class Crawler
    attr_accessor :movies_limit,:tags_limit
    def initialize
      @domain ||= Env::XVIDES_URL_WWW
      @iframe_url ||= Env::XVIDES_IFRAME_URL
      @movies_limit ||= -1
      @tags_limit ||= -1
    end

    def get_data_from(url,from)
      begin
        source = html(url)
        if from == 'movie'
          return parsed_movie_data(source)
        elsif from == 'taglist'
          return parsed_tag_data(source)
        else
          return {}
        end
      rescue Exception => e
        raise e
      end
    end

private
    def html(url)
      begin
        return Nokogiri.HTML(open(url).read)
      rescue Exception => e
        raise e
      end
    end

    # main crawler
    def parsed_movie_data(data)
      parsed_data = []
      index       = 0

      data.search(".thumb-block .thumb-inside").each do |post|
        data = {}
        begin
          # limit
          break if @movies_limit == index
          # thumbnail infomation
          post.search('div[@class="thumb"]/a').each do |a|
            data['movie_page_url'] = "#{@domain}#{a.attribute('href').value}"
            data['movie_thumnail_url'] = "#{a.children.attribute('src').value}"
          end

          # if script tag is contained
          post.search('script').each do |elm|
            data['movie_page_url'] = @domain + (elm.children[0].content.match(/href="(.+?)">/))[1]
            data['movie_thumnail_url'] = (elm.children[0].content.match(/src="(.+?)"/))[1]
          end

          # movie_id
          data['movie_id'] = data['movie_page_url'].match(/\/video(\d+)\/.*/)[1].to_i

          # iframe url
          data['movie_url'] = @iframe_url + (data['movie_page_url'].match(/\/video(\d+)\/.*/))[1]

          # description
          data['description'] = ''
          post.search('p/a').each do |a|
            data['description'] = a.inner_text
          end

          # metadata
          post.search('p[@class="metadata"]/span[@class="bg"]').each do |span|
            text = span.inner_text.gsub(/(\t|\s|\n)+/,'')
            data['duration'] = duration_to_min((text.match(/\(.+\)/))[0])
            data['movie_quality'] = quality_to_per(text.sub(/\(.+\)/,''))
          end
          index += 1
          parsed_data << data
        rescue Exception => e
          raise e
        end
      end
      return parsed_data
    end

    # e.g. (1h13min)
    def duration_to_min(duration_str)
      match = duration_str.match(/((?<hour>\d+)h)*((?<min>\d+)min)/)
      match[:hour].to_i * 60 + match[:min].to_i
    end

    # e.g. Pornquality:87%
    def quality_to_per(quality_str)
      quality_str.match(/\d+/)[0].to_i
    end

    # tag list crawler
    def parsed_tag_data(data)
        parsed_data = {}
        index       = 0
        data.xpath('//div[@id="main"]/ul[@id="tags"]/li').each do |li|
          begin
            # limit
            break if @tags_limit == index
            parsed_data[index] = {}
            # tag info
            parsed_data[index]['tag_name'] = li.children.children.inner_text
            parsed_data[index]['tag_url'] = "#{@domain}#{li.children.attribute('href').value}"
            parsed_data[index]['tag_count'] = li.inner_text.sub(/.+\s/,'')
            index += 1
          rescue Exception => e
            raise e
          end
        end
        return parsed_data
    end
  end
end
