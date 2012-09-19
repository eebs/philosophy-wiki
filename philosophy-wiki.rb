require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'redis'
require 'digest/sha1'

def sha1(data)
    Digest::SHA1.hexdigest data
end

def strip_parens(data)
    d = 0
    k = 0
    out = ''
    data.each_char do |i|
        if d < 1 then
            k -= 1 if i == '>'
            k += 1 if i == '<'
        end
        #check for parentheses
        if k < 1 then
            d += 1 if i == '('

            if d > 0 then
                out += ''
            else
                out += i
            end

            d -= 1 if i == ')'
        else
            out += i
        end
    end
    out
end

def get_random_url()
    randomUrl = "http://en.wikipedia.org/wiki/Special:Random"

    randomPage = nil
    open(randomUrl) do |resp|
        randomPage = resp.base_uri.to_s
    end
end

def has_an_a_tag(data)
    data.at_css('a')
end


def get_first_ptag(doc)
    p_children = doc.at_css('#mw-content-text')>('p')
    p_children.first
end

def ensure_has_atag(ptag)
    while !has_an_a_tag(ptag) || ptag.node_name != 'p' do
        ptag = ptag.next_sibling()
    end
    ptag
end

def get_first_atag(doc)
    while doc.at_css('sup') do
        doc.at_css('sup').remove
    end
    doc.at_css('a').attr('href')
end

def get_new_url(doc)
    # Get the first 'p' tag in the main content area
    first_ptag = get_first_ptag(doc)
    # Ensure the ptag has an 'a' tag
    ptag = ensure_has_atag(first_ptag)
    # Remove stuff in ()
    filtered_ptag = strip_parens(ptag.to_s)
    # Create new doc from filtered data
    filtered_doc = Nokogiri::HTML(filtered_ptag)
    # Get the first link
    first_link = get_first_atag(filtered_doc)
    # Create the new url
    newurl = $base_url + first_link
end

def process_url(url)
    id = sha1(url)

    # Are we in a loop?
    if $visited[id] then
        puts "Oh noes, loopy!"
        return false
    end
    # Not in loop, add current to hash
    $visited[id] = true

    doc = Nokogiri::HTML(open(url))
    title = doc.title

    if memio = $redis.get(id) then
        puts 'Stopping at ' + memio
        $redis.set(id, title)
        return true
    end

    puts title
    puts url

    if(title == 'Philosophy - Wikipedia, the free encyclopedia')
        $redis.set(id, title)
        puts 'Done!'
        return true
    end

    newurl = get_new_url(doc)
    if process_url(newurl) then
        $redis.set(id, title)
        return true
    end
end

def run(infinite = false)
    $visited = Hash.new
    url = get_random_url
    process_url(url)

    while infinite
        url = get_random_url
        process_url(url)
    end
end

$base_url = 'http://en.wikipedia.org'
$redis = Redis.new

begin
    run
rescue Exception => e
    puts 'Uh oh, something bad happened.'
end

