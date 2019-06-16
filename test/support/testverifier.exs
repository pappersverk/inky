defmodule Inky.TestVerifier do
  defmodule MockInteractionException do
    defexception message: "Interaction with mock did not match expectation.",
                 description: nil,
                 issue: nil,
                 item: -1

    def unmet(reason, item) do
      %MockInteractionException{
        description: "Wrong interaction",
        issue: {:unmet, reason},
        item: item
      }
    end

    def expected(spec, item) do
      %MockInteractionException{
        description: "Missing interactions",
        issue: {:expected, spec},
        item: item
      }
    end

    def unexpected(actual, item) do
      %MockInteractionException{
        description: "Unexpected interactions",
        issue: {:unexpected, actual},
        item: item
      }
    end
  end

  def load_spec(path, prefix \\ "") do
    prefix
    |> Path.join(path)
    |> File.read!()
    |> parse_spec()
  end

  def check(spec, actual, items \\ 0) do
    case {spec, actual} do
      {[], []} ->
        {:ok, items}

      {spec, []} ->
        throw(MockInteractionException.expected(spec, items + 1))

      {[], actual} ->
        throw(MockInteractionException.unexpected(actual, items + 1))

      {[s | spec_rest], [a | actual_rest]} ->
        case check_step(s, a) do
          :cont -> check(spec_rest, actual_rest, items + 1)
          {:halt, reason} -> throw(MockInteractionException.unmet(reason, items + 1))
        end
    end
  end

  def parse_spec(str) when is_binary(str) do
    str
    |> Code.string_to_quoted!()
    |> do_parse_spec()
  end

  # atomic terms
  defp do_parse_spec(term) when is_atom(term), do: term
  defp do_parse_spec(term) when is_integer(term), do: term
  defp do_parse_spec(term) when is_float(term), do: term
  defp do_parse_spec(term) when is_binary(term), do: term

  defp do_parse_spec([]), do: []
  defp do_parse_spec([h | t]), do: [do_parse_spec(h) | do_parse_spec(t)]

  defp do_parse_spec({a, b}), do: {do_parse_spec(a), do_parse_spec(b)}

  defp do_parse_spec({:<<>>, _place, terms}) do
    :erlang.list_to_binary(terms)
  end

  defp do_parse_spec({:{}, _place, terms}) do
    terms
    |> Enum.map(&do_parse_spec/1)
    |> List.to_tuple()
  end

  defp do_parse_spec({:%{}, _place, terms}) do
    for {k, v} <- terms, into: %{}, do: {do_parse_spec(k), do_parse_spec(v)}
  end

  # to ignore functions and operators
  defp do_parse_spec({_term_type, _place, terms}), do: terms

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
