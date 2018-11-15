defmodule Ejoy.Jiffy do
  @decode_opt [:return_maps, :use_nil]
  @encode_opt [:force_utf8, :use_nil]

  def encode!(data) do
    :jiffy.encode(data, @encode_opt)
  end

  def encode(data) do
    try do
      {:ok, encode!(data)}
    catch
      _, _ -> {:error, :badarg}
    end
  end

  def decode!(bin, key_type \\ nil)
  def decode!(bin, nil) do
    :jiffy.decode(bin, @decode_opt)
  end
  def decode!(bin, key_type) do
    decode!(bin, nil) |> adapt_key(key_type)
  end

  def decode(bin, key_type \\ nil) do
    try do
      {:ok, decode!(bin, key_type)}
    catch
      _, _ -> {:error, :badarg}
    end
  end

  # decode出来的dict应该全是 map ，不会有 keyword 的形式
  # json decode 出来 key 的只能是 string
  def adapt_key(data, label) when is_map(data) do
    for {k, v} <- data, into: %{} do
      {to_atom(k, label), adapt_key(v, label)}
    end
  end
  def adapt_key(data, label) when is_list(data) do
    for l <- data, into: [], do: adapt_key(l, label)
  end
  def adapt_key(data, _label), do: data

  defp to_atom(str, :existing_atom) when is_binary(str) do
    String.to_existing_atom(str)
  end
  defp to_atom(str, :atom) when is_binary(str) do
    String.to_atom(str)
  end
end
