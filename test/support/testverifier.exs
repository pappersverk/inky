defmodule Inky.TestVerifier do
  defmodule MockInteractionException do
    defexception message: "Interaction with mock did not match expectation.",
                 description: nil,
                 issue: nil,
                 line: 0

    def unmet(reason, line) do
      %MockInteractionException{
        description: "Wrong interaction",
        issue: {:unmet, {line, reason}}
      }
    end

    def expected(spec, line) do
      %MockInteractionException{
        description: "Missing interactions",
        issue: {:expected, spec},
        line: line
      }
    end

    def unexpected(actual, line) do
      %MockInteractionException{
        description: "Unexpected interactions",
        issue: {:unexpected, actual},
        line: line
      }
    end
  end

  def store(spec, path, prefix \\ "") do
    bin = :erlang.term_to_binary(spec)

    prefix
    |> Path.join(path)
    |> File.write!(bin, [:write])
  end

  def load(path, prefix \\ "") do
    prefix
    |> Path.join(path)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def check(spec, actual, lines \\ 0) do
    case {spec, actual} do
      {[], []} ->
        {:ok, lines}

      {spec, []} ->
        throw(MockInteractionException.expected(spec, lines))

      {[], actual} ->
        throw(MockInteractionException.unexpected(actual, lines))

      {[s | spec_rest], [a | actual_rest]} ->
        case check_step(s, a) do
          :cont -> check(spec_rest, actual_rest, lines + 1)
          {:halt, reason} -> throw(MockInteractionException.unmet(reason, lines))
        end
    end
  end

  # check "don't care"
  defp check_step(:_, _), do: :cont

  # check bitstrings
  defp check_step(:bitstring, b) when is_bitstring(b), do: :cont
  defp check_step(:bitstring, bad), do: mismatch(:bitstring, bad)

  # check keys in tuples
  defp check_step({:_, sv}, {_ak, av}), do: check_step(sv, av)
  defp check_step({:bitstring, sv}, {b, av}) when is_bitstring(b), do: check_step(sv, av)
  defp check_step({spec_key, sv}, {spec_key, av}), do: check_step(sv, av)
  defp check_step({spec_key, _sv}, {bad_key, _av}), do: mismatch(spec_key, bad_key)

  # check exact match, last resort
  defp check_step(term, term), do: :cont
  defp check_step(term, bad), do: mismatch(term, bad)

  defp mismatch(spec, actual), do: {:halt, %{expected: spec, actual: actual}}
end
