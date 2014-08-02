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

  @doc """
  Takes two streams and creates a combined stream of form {left, right} using the most recent
  elements emitted by the two input streams. No elements are emitted from the returned stream
  until both input streams have emitted elements.
  """
  @spec combine_latest(Enumerable.t, Enumerable.t) :: Enumerable.t
  def combine_latest(stream1, stream2) do
    left = Stream.map(stream1, &({:left, &1}))
    right = Stream.map(stream2, &({:right, &1}))
    Streamz.merge([left, right])
    |> Stream.scan({nil,nil}, fn(el, {left, right}) ->
      case el do
        {:left,_} -> {el,right}
        {:right,_} -> {left,el}
      end
    end)
    |> Stream.drop_while(fn {a,b} -> a == nil or b == nil end)
    |> Stream.map(fn {{_,a},{_,b}} -> {a,b} end)
  end
end
