module ResponseJson
  def json
    JSON.parse(response.body)
  end

  def json_data
    json["data"] || []
  end

  def json_meta
    json["meta"] || {}
  end
end
