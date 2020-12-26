defmodule KdExpanders.CLI do
  def main(args \\ []) do
    options = [switches: [cmd: :string], aliases: [c: :cmd]]
    {opts, _, _} = OptionParser.parse(args, options)

    # IO.inspect(opts, label: "Command Line Arguments")

    stdio = IO.stream(:stdio, :line)

    stdio
    |> run_command_for_stream(opts[:cmd])
    |> Stream.into(stdio)
    |> Stream.run()
  end

  def run_command_for_stream(in_stream, "expand_function") do
    in_stream
    |> Stream.take(1)
    |> Stream.map(&KdExpanders.ExpandFunction.expand_line/1)
  end

  def run_command_for_stream(in_stream, _cmd), do: in_stream
end
