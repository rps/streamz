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
    func = fun
    Streamz.merge(first, second)
    |> Stream.transform({nil,nil}, fn(el, acc) ->
      case acc do
        {nil,nil} ->
          case el do
            {1,_} -> {nil, {el, nil}}
            {2,_} -> {nil, {nil, el}}
          end
        {a,nil} ->
          case el do
            {1,_} -> {nil,{el,nil}}
            {2,_} -> {{a,el},{a,el}}
          end
        {nil,b} ->
          case el do
            {1,_} -> {{el,b},{el,b}}
            {2,_} -> {nil,{nil,el}}
          end
        {a,b} ->
          case el do
            {1,_} ->
              {{el,b},{el,b}}
            {2,_} ->
              {{a,el},{a,el}}
          end
      end
    end)
    |> Stream.drop_while &(&1 == nil)
    |> Stream.map fn {a,b} ->
      func(a,b)
    end
  end
end