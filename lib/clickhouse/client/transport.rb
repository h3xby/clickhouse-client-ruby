require 'faraday'
require 'uri'

class Clickhouse::TransportError < RuntimeError; end

module Clickhouse::Client::Transport
  def initialize_connection(options={})
    url = options[:url]
    uri = URI(url)
    params = uri.query ? URI.decode_www_form(uri.query) : {}
    @conn = Faraday.new(url: url, params: params) do |faraday|
      faraday.request :multipart
      faraday.request :url_encoded
      faraday.adapter :net_http_persistent
    end
  end

  def exec(raw_sql, options)
    params = {query: raw_sql}

    body = options[:body]
    temp_data = options[:template_data]

    if temp_data
      raise "Cannot specify body body and template_data" if body
      body = {}
      merge_temp_data(body, params, temp_data)
    end

    resp = conn.post do |req|
      req.params.merge!(params)
      req.body = body
    end

    raise Clickhouse::TransportError.new(resp.body) if resp.status != 200
    resp.body
  end

  protected

  attr_reader :conn

  def merge_temp_data(body, params, data)
    data.each do |key, value|
      next unless value[:io]

      body[key] = value[:io]

      format = value[:format]
      params["#{key}_format"] = format if format

      structure = value[:structure]
      params["#{key}_structure"] = structure if structure

      types = value[:types]
      params["#{key}_types"] = types if types
    end
  end
end
