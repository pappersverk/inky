defmodule Inky.TestVerifierTest do
  use ExUnit.Case

  alias Inky.TestVerifier
  alias Inky.TestVerifier.MockInteractionException

  import TestVerifier, only: [check: 2]

  describe "success cases" do
    test "trivial examples" do
      # base case
      assert check([], []) == {:ok, 0}

      # simple specs
      assert check([:_], [:foo]) == {:ok, 1}
      assert check([:bitstring], ["hey hey"]) == {:ok, 1}
      assert check([:bitstring], [<<5::7>>]) == {:ok, 1}
      assert check([:some_term], [:some_term]) == {:ok, 1}
      assert check([{:foo, 1}], [{:foo, 1}]) == {:ok, 1}
    end
  end

  describe "various failures" do
    test "unmet expectation" do
      %MockInteractionException{issue: {:unmet, _}} =
        try do
          check(["interaction 1"], ["INTERACTION 1"])
        catch
          e -> e
        end
    end

    test "missing interactions" do
      %MockInteractionException{issue: {:expected, _}} =
        try do
          check(["interaction 1"], [])
        catch
          e -> e
        end
    end

    test "extraneous interactions" do
      %MockInteractionException{issue: {:unexpected, _}} =
        try do
          check([], ["interaction 1"])
        catch
          e -> e
        end
    end
  end
end
