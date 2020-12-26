defmodule KdExpanders.ExpandFunction do
  @moduledoc false

  def expand_line(line) do
    with {:ok, parts} <- parse_line(line),
         {:ok, params} <- parse_params(parts["params"]),
         {:ok, processed_params} <- handle_params(params),
         {:ok, processed_line} <- rebuild_line(parts, processed_params) do
      processed_line
    else
      _ ->
        line
    end
  end

  def rebuild_line(parts, processed_params) do
    new_param_str =
      processed_params
      |> Enum.map(fn {param_str, _clauses} -> param_str end)
      |> Enum.join(",")

    new_guard_str =
      processed_params
      |> Enum.flat_map(fn {_param_str, clauses} -> clauses end)
      |> Enum.filter(fn
        "" -> false
        _str -> true
      end)
      |> Enum.join(" and ")
      |> case do
        "" -> nil
        guard_str -> guard_str
      end

    post_str = parts["post"]

    post_str =
      if new_guard_str do
        if String.contains?(post_str, " when ") do
          post_str |> String.replace(" when ", " when #{new_guard_str} and ")
        else
          " when " <> new_guard_str <> post_str
        end
      else
        post_str
      end

    line = ~s|#{parts["pre"]}#{parts["def"]} #{parts["fun"]}(#{new_param_str})#{post_str}|

    {:ok, line}
  end

  def handle_params(params) do
    processed_params =
      params
      |> Enum.map(&handle_param/1)

    {:ok, processed_params}
  end

  def handle_param({param_names, param_str}) do
    {param_str, clauses} =
      param_names
      |> Enum.reduce({param_str, []}, fn param_name, {param_str, clauses} ->
        {new_param_str, clause} = parse_param({param_name, param_str})

        {new_param_str, [clause | clauses]}
      end)

    {param_str, clauses}
  end

  def parse_param({param_name, param_str}) when is_binary(param_name) do
    # {param_name, param_str} |> IO.inspect(label: "parse_param ")
    handle_type({param_name, param_str}, String.last(param_name))
    # |> IO.inspect(label: "➜ ")
  end

  def handle_type({param_name, param_str}, char = "A") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_atom(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "B") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_binary(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "F") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_float(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "I") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_integer(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "L") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_list(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "M") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_map(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "S") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_struct(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, char = "T") do
    new_param_name = String.replace_trailing(param_name, char, "")
    new_param_str = String.replace(param_str, param_name, new_param_name)
    clause = "is_tuple(#{new_param_name})"
    {new_param_str, clause}
  end

  def handle_type({param_name, param_str}, _), do: {{param_name, param_str}, ""}

  def parse_line(str) do
    Regex.named_captures(
      ~r/^(?<pre>.*)(?<def>def\w*) (?<fun>[a-z0-9_?]+)\((?<params>[^)]*)\)(?<post>.*)$/,
      str
    )
    |> case do
      nil -> {:error, "cannot parse"}
      parts -> {:ok, parts}
    end
  end

  def parse_params(str) do
    str
    |> String.split(",")
    |> Enum.map(&extract_paramname/1)
    |> case do
      params when is_list(params) and length(params) > 0 -> {:ok, params}
      nil -> {:error, "cannot parse params"}
    end
  end

  def extract_paramname(param_str) do
    Code.string_to_quoted("def function(#{param_str}) do end")
    |> case do
      {:ok, {:def, [line: 1], [{:function, [line: 1], ast}, _do]}} ->
        {get_param_from_ast(ast), param_str}

      {_, _} ->
        # fallback
        param_name =
          param_str
          |> String.replace(~r/\\.*$/, "")
          |> String.replace(~r/^=.*$/, "")
          |> String.trim()

        {param_name, param_str}
    end
  end

  def traverse({form, meta, args}, acc) do
    # form |> IO.inspect(label: "traverse")

    acc =
      if param_name_needs_handling?("#{form}") do
        ["#{form}" | acc]
      else
        acc
      end

    {{form, meta, args}, acc}
  end

  def traverse(node, acc), do: {node, acc}

  def param_name_needs_handling?(param_name) do
    Enum.member?(~w(I M L B), String.last(param_name))
  end

  def get_param_from_ast(ast) do
    {ast, params_to_handle} = Macro.prewalk(ast, [], &traverse/2)
    params_to_handle
  end
end
