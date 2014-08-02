defmodule Streamz do
  @moduledoc """
  Module for creating and composing streams.

  Streamz is meant to complement the Stream module.
  """

  @doc """
  Creates a composite stream. The stream emits values from the underlying streams, in the
  order they are produced. This differs from `Stream.zip/2`, where the order of values is
  strictly alternating between the source streams.
  """
  @spec merge([Enumerable.t]) :: Enumerable.t
  def merge(streams) do
    Streamz.Merge.build_merge_stream(streams)
  end

  @doc """
  Takes elements from the first stream until the second stream produces data.
  """
  @spec take_until(Enumerable.t, Enumerable.t) :: Enumerable.t
  def take_until(stream, cutoff) do
    ref = make_ref
    wrapped_cutoff = cutoff |> Stream.map fn (_) ->
      ref
    end
    Streamz.merge([stream, wrapped_cutoff])
      |> Stream.take_while &( &1 != ref )
  end

  def combine_latest_two(stream1, stream2, fun) do
    first = Stream.map(stream1, &({1, &1}))
    second = Stream.map(stream2, &({2, &1}))
    parent = self
    pid = spawn_link fn ->
      func = fun
      Streamz.merge(first, second) |> Enum.reduce(fn el, {nil, nil}, {a,b} ->
        receive do
          {:get, parent} ->
            case el do
              {1,_} ->
                unless a == nil or b == nil do
                  send parent, func(el, b)
                end
                {el,b}
              {2, _} ->
                unless a == nil or b == nil do
                  send parent, func(a, el)
                end
                {a, el}
            end
        end
      end)
    end
  end
end
