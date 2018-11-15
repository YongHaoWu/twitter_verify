defmodule Ejoy.HttpRPC do
  require Logger 
  
  def post(api, req, content_type \\'application/x-www-form-urlencoded', opts \\ [], headers \\ [])
  def post(api, req, content_type, opts, headers) when is_binary(api) do
    post(to_charlist(api), req, content_type, opts, headers)
  end

  def post(api, req, content_type, opts, headers) when is_binary(content_type) do
    post(api, req, to_charlist(content_type), opts, headers)
  end

  def post(api, req, content_type, opts, headers) do
    body = case content_type do
      'application/x-www-form-urlencoded' ->
        URI.encode_query(req)
      'application/json' ->
        Ejoy.Jiffy.encode!(req)
      _ -> req
    end
    
    options = make_opts(opts)
    profile = make_profile(opts)
    post_loop(api, headers, content_type, body, options, profile, 3)
  end
  
  defp post_loop(api, headers, content_type, body, options, profile, n) do
    headers = transfer_to_charlist(headers)

    case :httpc.request(:post, 
      {api, headers, content_type, body}, 
      [ssl: [verify: 0]], options, profile) do
      {:ok, {status_line, _headers, resp_body}} ->
        {_, status_code, _} = status_line
        case status_code do
          200 ->
            {:ok, resp_body}
          error_code ->
            Logger.debug("http post fail: #{error_code}, #{inspect(resp_body)}")
            {:fail, error_code}
        end
      {:error, :socket_closed_remotely} ->
        if n == 0 do
          Logger.debug("post http error socket_closed_remotely, API is #{api}, headers: #{inspect(headers)}")
          {:fail, 500}
        else
          post_loop(api, headers, content_type, body, options, profile, n-1)
        end
      {:error, reason} ->
        Logger.debug("post http error #{inspect(reason)}, API is #{api}, headers: #{inspect(headers)}")
        {:fail, 500}
    end
  end
  
  def transfer_to_charlist(data) when is_list(data) do
    Enum.map(data, fn x->
      {
        elem(x, 0) |> to_charlist,
        elem(x, 1) |> to_charlist,
      }
    end)
  end
  
  def json_post(api, req, opts \\ [], headers \\ []) do
    case post(api, req, 'application/x-www-form-urlencoded', opts, headers) do
      {:ok, resp} ->
        decode_json(resp)
      error ->
        error
    end
  end

  def application_json_post(api, req, opts \\ [], headers \\ []) do
    case post(api, req, 'application/json', opts, headers) do
      {:ok, resp} ->
        decode_json(resp)
      error ->
        error
    end
  end
  
  def get(api, req, opts \\ [], headers \\ [])

  def get(api, req, opts, headers) when is_binary(api) do
    get(to_charlist(api), req, opts, headers)
  end

  def get(api, req, opts, headers) do
    body = URI.encode_query(req) |> String.to_charlist
    url = case length(body) do
      0 -> api
      _ ->
        case List.last(api)  == '?' do
          true -> api ++ body
          false -> api ++ '?' ++ body
        end
    end
    options = make_opts(opts)
    profile = make_profile(opts)
    headers = transfer_to_charlist(headers)
    case :httpc.request(:get, 
      {url, headers}, 
      [ssl: [verify: 0]], options, profile) do
        {:ok, {status_line, _headers, resp_body}} ->
        {_, status_code, _} = status_line
        case status_code do
          200 ->
            {:ok, resp_body} 
          error_code ->
            Logger.debug("http get fail: #{error_code}, #{inspect(resp_body)}")
            {:fail, error_code}
        end
      {:error, reason} ->
        Logger.debug("get http error: #{inspect(reason)}, API is #{api}")
        {:fail, 500}
    end
  end

  def json_get(api, req \\ %{}, opts \\ [], headers \\ []) do
    case get(api, req, opts, headers) do
      {:ok, resp} ->
        decode_json(resp)
      error ->
        error
    end
  end

  defp decode_json(resp) do
    case Ejoy.Jiffy.decode(resp) do
      {:ok, _} = ret ->
        ret
      _ ->
        Logger.debug("json decode error")
        {:fail, 500}
    end
  end

  defp make_opts(opts) do
    format = Keyword.get(opts, :body_format, :binary)
    [body_format: format]
  end

  defp make_profile(opts) do
    Keyword.get(opts, :proxy, :default)
  end
end
